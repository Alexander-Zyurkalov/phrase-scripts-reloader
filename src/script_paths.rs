use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
use anyhow::{anyhow, Result};
use sanitize_filename::{sanitize_with_options, Options};
use std::collections::HashMap;
use std::fs;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::rc::Rc;

pub struct ScriptPathRegistry {
    song_path: PathBuf,
    paths: HashMap<InstrumentIndex, HashMap<PhraseIndex, Rc<Path>>>,
    paths_to_ids: HashMap<Rc<Path>, (InstrumentId, PhraseId)>,
}

impl ScriptPathRegistry {
    pub fn new(song_path: impl Into<PathBuf>) -> Self {
        ScriptPathRegistry {
            song_path: song_path.into(),
            paths: HashMap::new(),
            paths_to_ids: HashMap::new(),
        }
    }

    pub fn update_song_path(&mut self, song_path: impl Into<PathBuf>) -> &Path {
        self.song_path = song_path.into();
        self.song_path.as_path()
    }

    pub fn get_song_path(&self) -> &Path {
        self.song_path.as_path()
    }

    pub fn register_path(
        &mut self,
        instrument_id: InstrumentId,
        instrument_index: InstrumentIndex,
        instrument_name: impl AsRef<str>,
        phrase_id: PhraseId,
        phrase_index: PhraseIndex,
        phrase_name: impl AsRef<str>,
    ) -> Result<Rc<Path>> {
        let phrases = self.paths.entry(instrument_index).or_default();
        if phrases.contains_key(&phrase_index) {
            return Err(anyhow!("The path is already registered"));
        }
        let path: Rc<Path> = Self::make_script_path(
            &self.song_path,
            instrument_index,
            instrument_name.as_ref(),
            phrase_index,
            phrase_name.as_ref(),
        )?
        .into();

        self.paths_to_ids.insert(path.clone(), (instrument_id, phrase_id));
        // TODO: use match phrases.entry(...)
        Ok(phrases.entry(phrase_index).or_insert(path).clone())
    }

    pub fn get_path(
        &self,
        instrument_index: InstrumentIndex,
        phrase_index: PhraseIndex,
    ) -> Option<Rc<Path>> {
        self.paths.get(&instrument_index)?.get(&phrase_index).cloned()
    }

    pub fn get_ids(&self, path: &Rc<Path>) -> Option<(InstrumentId, PhraseId)> {
        self.paths_to_ids.get(path).copied()
    }

    pub fn unregister_path(
        &mut self,
        instrument_index: InstrumentIndex,
        phrase_index: PhraseIndex,
    ) -> Option<Rc<Path>> {
        let path = self.paths.get_mut(&instrument_index)?.remove(&phrase_index);
        if let Some(path) = path.clone() {
            self.paths_to_ids.remove(&path);
        }
        path
    }

    pub fn make_instrument_path(
        song_path: &Path,
        instrument_index: InstrumentIndex,
        instrument_name: &str,
    ) -> Result<PathBuf> {
        let sanitize_options = Options { replacement: "-", windows: true, truncate: true };
        let instrument_file_name = format!(
            "{}-{}",
            instrument_index,
            sanitize_with_options(instrument_name, sanitize_options.clone())
        )
            .replace(" ", "-");
        let instrument_path =
            if song_path.is_dir() { song_path.to_path_buf() } else { song_path.with_extension("") }
                .join("lua-scripts")
                .join(instrument_file_name);
        Self::create_and_canonicalize(instrument_path, false)
    }
}

impl ScriptPathRegistry {
    fn make_script_path(
        song_path: impl AsRef<Path>,
        instrument_index: InstrumentIndex,
        instrument_name: &str,
        phrase_index: PhraseIndex,
        phrase_name: &str,
    ) -> Result<PathBuf> {
        let song_path = song_path.as_ref();
        let instrument_path =
            Self::make_instrument_path(song_path, instrument_index, instrument_name)?;
        let sanitize_options = Options { replacement: "-", windows: true, truncate: true };

        let phrase_sanitized = format!(
            "{}-{}",
            phrase_index,
            sanitize_with_options(phrase_name, sanitize_options.clone())
        )
        .replace(" ", "-");

        let script_file_name = format!("{}.lua", phrase_sanitized);
        let path = instrument_path.join(script_file_name);
        Self::create_and_canonicalize(path, true)
    }


    fn create_and_canonicalize(path: PathBuf, create_file: bool) -> Result<PathBuf> {
        if !path.exists() {
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            if create_file {
                File::create(path.as_path())?;
            }
        }
        Ok(path.canonicalize().unwrap_or_else(|_| path))
    }
}

#[cfg(test)]
mod test {
    use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
    use crate::script_paths::ScriptPathRegistry;
    use tempfile::TempDir;

    #[test]
    fn make_script_path_makes_usable_path() {
        let tmp_dir = TempDir::new().unwrap();

        let song_path = tmp_dir.path().join("filename.xrns");
        let instrument_name = "Violin / Special";
        let phrase_name = "Intro: Part 1";

        let generated_script_path = ScriptPathRegistry::make_script_path(
            song_path,
            InstrumentIndex::try_from(1).unwrap(),
            instrument_name,
            PhraseIndex::try_from(1).unwrap(),
            phrase_name,
        )
        .unwrap();

        let path_buf = tmp_dir.as_ref().canonicalize().unwrap();
        let dir_path_str: &str = path_buf.to_str().unwrap();
        assert!(generated_script_path.to_str().unwrap().contains(dir_path_str));

        let _ = generated_script_path.parent().unwrap();

        assert_eq!(
            generated_script_path.to_str().unwrap(),
            format!(
                "{}/{}",
                dir_path_str, "filename/lua-scripts/001-Violin---Special/001-Intro--Part-1.lua"
            )
        );
    }

    #[test]
    fn register_unregister_path_test() {
        let mut registry = ScriptPathRegistry::new("/tmp/song.xrns");

        let instrument_id = InstrumentId::from(1);
        let instrument_index = InstrumentIndex::try_from(1).unwrap();
        let instrument_name = "Piano";
        let phrase_id = PhraseId::from(1);
        let phrase_index = PhraseIndex::try_from(1).unwrap();
        let phrase_name = "Main";

        let registered_path = registry.register_path(
            instrument_id,
            instrument_index,
            instrument_name,
            phrase_id,
            phrase_index,
            phrase_name,
        );
        assert!(
            registered_path.is_ok(),
            "register_path should return Ok, {:?}",
            registered_path.err()
        );
        let another_try = registry.register_path(
            instrument_id,
            instrument_index,
            instrument_name,
            phrase_id,
            phrase_index,
            "another phrase",
        );
        assert!(another_try.is_err());

        let retrieved_path = registry.get_path(instrument_index, phrase_index);
        assert!(retrieved_path.is_some());

        registry.unregister_path(instrument_index, phrase_index);

        let retrieved_path_after_unregister = registry.get_path(instrument_index, phrase_index);
        assert!(retrieved_path_after_unregister.is_none());
    }
}
