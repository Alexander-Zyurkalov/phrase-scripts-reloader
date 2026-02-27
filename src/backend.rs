use crate::file_changes_monitor::FileChangesMonitor;
use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
use crate::instrument_registry::InstrumentRegistry;
use crate::script_paths::ScriptPathRegistry;
use anyhow::{anyhow, Context, Result};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct ScriptChange {
    pub instrument_id: InstrumentId,
    pub instrument_name: Rc<str>,
    pub phrase_id: PhraseId,
    pub phrase_name: Rc<str>,
    pub script_body: String,
}

pub struct Backend {
    file_changes_monitor: FileChangesMonitor,
    script_path_registry: ScriptPathRegistry,
    instrument_registry: InstrumentRegistry,
}

// public functions
impl Backend {
    pub fn new(song_path: impl Into<PathBuf>, monitoring_interval: Duration) -> Self {
        let buf = song_path.into();
        let path: &str = buf.to_str().unwrap();

        Self {
            file_changes_monitor: FileChangesMonitor::new(monitoring_interval),
            script_path_registry: ScriptPathRegistry::new(buf),
            instrument_registry: InstrumentRegistry::new(),
        }
    }

    pub fn update_song_path(&mut self, song_path: impl Into<PathBuf>) -> Result<()> {
        let mut content: HashMap<(InstrumentId, PhraseId), String> = HashMap::new();
        let instrument_ids = self.instrument_registry.get_all_instrument_ids();
        for instrument_id in &instrument_ids {
            let instrument_index = self.instrument_registry.get_instrument_index(*instrument_id)?;
            let phrase_ids = self.instrument_registry.get_all_phrase_ids(*instrument_id);
            for (phrase_id, phrase_index) in phrase_ids {
                let path = self.unregister_and_unwatch(instrument_index, phrase_index)?;
                content.insert((*instrument_id, phrase_id), fs::read_to_string(path)?);
            }
        }

        self.script_path_registry.update_song_path(song_path);

        for instrument_id in instrument_ids {
            let phrase_ids = self.instrument_registry.get_all_phrase_ids(instrument_id);
            let instrument_name = self.instrument_registry.get_instrument_name(instrument_id)?;
            for (phrase_id, _) in phrase_ids {
                let phrase_name =
                    self.instrument_registry.get_phrase_name(instrument_id, phrase_id)?;
                self.register_script(
                    instrument_id,
                    &*instrument_name,
                    phrase_id,
                    &*phrase_name,
                    content.get(&(instrument_id, phrase_id)),
                )?;
            }
        }
        Ok(())
    }

    pub fn register_script(
        &mut self,
        instrument_id: InstrumentId,
        instrument_name: impl AsRef<str>,
        phrase_id: PhraseId,
        phrase_name: impl AsRef<str>,
        script_body: Option<impl AsRef<str>>,
    ) -> Result<Rc<Path>> {
        let (instrument_index, phrase_index) =
            self.instrument_registry.get_indexes(instrument_id, phrase_id)?;

        self.instrument_registry.set_instrument_name(instrument_id, &instrument_name);
        self.instrument_registry.set_phrase_name(instrument_id, phrase_id, &phrase_name);

        let script_body_str = script_body.map(|s| s.as_ref().to_string());

        let mut data_was_written = false;
        let write_data = |path: &Path| -> Result<()> {
            let is_empty_or_missing =
                !path.exists() || fs::metadata(path).map(|m| m.len() == 0).unwrap_or(false);

            if is_empty_or_missing {
                if let Some(ref body) = script_body_str {
                    fs::write(path, body)
                        .context(anyhow!("Failed to write script file: {:?}", path))?;
                    data_was_written = true;
                }
            }
            Ok(())
        };
        let script_path = self.register_and_watch(
            instrument_id,
            instrument_index,
            phrase_id,
            phrase_index,
            Some(write_data),
        )?;

        if data_was_written {
            self.file_changes_monitor.load_file(&script_path);
        }

        Ok(script_path)
    }

    pub fn unregister_script(
        &mut self,
        instrument_id: InstrumentId,
        phrase_id: PhraseId,
    ) -> Result<PathBuf> {
        let (instrument_index, phrase_index) =
            self.instrument_registry.get_indexes(instrument_id, phrase_id)?;

        let path = self.unregister_and_unwatch(instrument_index, phrase_index)?;
        let bak_path = Self::make_backup_path(&path, "lua.bak");

        fs::rename(path, &bak_path)?;
        self.instrument_registry.remove_phrase_name(instrument_id, phrase_id);
        Ok(bak_path)
    }

    pub fn rename_script(
        &mut self,
        instrument_id: InstrumentId,
        phrase_id: PhraseId,
        new_name: impl AsRef<str>,
    ) -> Result<()> {
        let (instrument_index, phrase_index) =
            self.instrument_registry.get_indexes(instrument_id, phrase_id)?;
        let old_path = self.unregister_and_unwatch(instrument_index, phrase_index)?;
        self.instrument_registry.set_phrase_name(instrument_id, phrase_id, new_name);

        let new_path = self.register_and_watch(
            instrument_id,
            instrument_index,
            phrase_id,
            phrase_index,
            None::<fn(&Path) -> Result<()>>,
        )?;
        if old_path != new_path {
            fs::rename(old_path, new_path)?
        }
        Ok(())
    }

    pub fn rename_instrument(
        &mut self,
        instrument_id: InstrumentId,
        new_instrument_name: impl AsRef<str>,
    ) -> Result<()> {
        let instrument_index = self.instrument_registry.get_instrument_index(instrument_id)?;
        let instrument_name = self.instrument_registry.get_instrument_name(instrument_id)?;
        let old_instrument_path = ScriptPathRegistry::make_instrument_path(
            self.script_path_registry.get_song_path(),
            instrument_index,
            instrument_name.as_ref(),
        )?;

        let phrases = self.instrument_registry.get_all_phrase_ids(instrument_id);
        let mut data: HashMap<PhraseIndex, String> = HashMap::with_capacity(phrases.len());
        for (_, phrase_index) in &phrases {
            let phrase_path = self.unregister_and_unwatch(instrument_index, *phrase_index)?;
            data.insert(*phrase_index, fs::read_to_string(&phrase_path)?);
            fs::rename(&phrase_path, Self::make_backup_path(&phrase_path, "bak"))?;
        }
        self.instrument_registry.set_instrument_name(instrument_id, &new_instrument_name);
        fs::rename(&old_instrument_path, Self::make_backup_path(&old_instrument_path, "bak"))?;

        for (phrase_id, phrase_index) in &phrases {
            let phrase_data = data.get(phrase_index);
            let write_data = |path: &Path| -> Result<()> {
                if let Some(phrase_data) = phrase_data {
                    fs::write(path, phrase_data)
                        .context(anyhow!("Failed to write script file: {:?}", path))?;
                }
                Ok(())
            };

            self.register_and_watch(
                instrument_id,
                instrument_index,
                *phrase_id,
                *phrase_index,
                Some(write_data),
            )?;
        }

        Ok(())
    }

    pub fn unregister_instrument(&mut self, instrument_id: InstrumentId) -> Result<()> {
        let phrases = self.instrument_registry.get_all_phrase_ids(instrument_id);
        let mut phrase_path: Option<PathBuf> = None;
        for (phrase_id, _) in phrases {
            phrase_path = self.unregister_script(instrument_id, phrase_id).ok();
        }
        if let Some(phrase_path) = phrase_path {
            let instrument_path =
                phrase_path.parent().context("No phrase path found for instrument")?;
            let backup_instrument_path = Self::make_backup_path(instrument_path, "bak");
            fs::rename(instrument_path, backup_instrument_path)?;
        }
        self.instrument_registry.remove_instrument(instrument_id);
        Ok(())
    }

    pub fn set_new_instrument_indexes(
        &mut self,
        id_index_pairs: impl AsRef<[(InstrumentId, InstrumentIndex)]>,
    ) {
        self.instrument_registry.set_instrument_indexes(id_index_pairs);
    }

    pub fn set_new_phrase_indexes(
        &mut self,
        instrument_id: InstrumentId,
        id_index_pairs: impl AsRef<[(PhraseId, PhraseIndex)]>,
    ) {
        self.instrument_registry.set_phrase_indexes(instrument_id, id_index_pairs);
    }

    pub fn take_changes(&mut self) -> Result<Vec<ScriptChange>> {
        let changes = self.file_changes_monitor.take_changes();
        let mut script_changes = Vec::with_capacity(changes.len());
        for change in changes {
            let path = Rc::from(change.path);
            if let Some((instrument_id, phrase_id)) = self.script_path_registry.get_ids(&path) {
                let instrument_name =
                    self.instrument_registry.get_instrument_name(instrument_id)?;
                let phrase_name =
                    self.instrument_registry.get_phrase_name(instrument_id, phrase_id)?;
                let script_body = change.text;

                let script_change = ScriptChange {
                    instrument_id,
                    instrument_name,
                    phrase_id,
                    phrase_name,
                    script_body,
                };
                script_changes.push(script_change);
            }
        }
        Ok(script_changes)
    }
}

// private functions
impl Backend {
    fn make_backup_path(path: impl AsRef<Path>, extension: &str) -> PathBuf {
        let mut bak_path = path.as_ref().with_extension(extension);
        let mut counter = 1;
        while bak_path.exists() {
            bak_path = path.as_ref().with_extension(format!("{}{}", extension, counter));
            counter += 1;
        }
        bak_path
    }

    fn register_and_watch<F>(
        &mut self,
        instrument_id: InstrumentId,
        instrument_index: InstrumentIndex,
        phrase_id: PhraseId,
        phrase_index: PhraseIndex,
        before_watch: Option<F>,
    ) -> Result<Rc<Path>>
    where
        F: FnOnce(&Path) -> Result<()>,
    {
        let instrument_name = self.instrument_registry.get_instrument_name(instrument_id)?;
        let phrase_name = self.instrument_registry.get_phrase_name(instrument_id, phrase_id)?;
        let script_path = self.script_path_registry.register_path(
            instrument_id,
            instrument_index,
            instrument_name,
            phrase_id,
            phrase_index,
            phrase_name,
        )?;

        if let Some(f) = before_watch {
            f(&script_path)?;
        }

        self.file_changes_monitor.watch_file(&script_path)?;
        Ok(script_path)
    }

    fn unregister_and_unwatch(
        &mut self,
        instrument_index: InstrumentIndex,
        phrase_index: PhraseIndex,
    ) -> Result<Rc<Path>> {
        let path = self
            .script_path_registry
            .unregister_path(instrument_index, phrase_index)
            .context("Failed to unregister path")?;
        self.file_changes_monitor.unwatch_file(&*path)?;
        Ok(path)
    }
}

// TODO: rename tests
#[cfg(test)]
mod test {
    use crate::backend::Backend;
    use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
    use std::fs;
    use std::fs::File;
    use std::path::Path;
    use std::rc::Rc;
    use std::time::Duration;
    use tempfile::TempDir;

    fn setup(song_name: impl AsRef<str>) -> (TempDir, std::path::PathBuf, Backend) {
        let tmp_dir = TempDir::new().unwrap();
        let song_path = tmp_dir.path().join(song_name.as_ref());
        let backend = Backend::new(&song_path, Duration::from_millis(100));
        (tmp_dir, song_path, backend)
    }

    fn test_take_changes(backend: &mut Backend, path: Rc<Path>) {
        fs::write(&*path, "test change").unwrap();
        let enough_time_to_wait_changes = 200;
        std::thread::sleep(Duration::from_millis(enough_time_to_wait_changes));
        let changes = backend.take_changes();
        assert!(changes.is_ok(), "Changes should be taken without errors: {:?}", changes.err());
        if let Ok(changes) = changes {
            assert!(changes.len() > 0, "There are must be some changes")
        }
    }
    fn test_no_changes(backend: &mut Backend, path: Rc<Path>) {
        if !path.exists() {
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).expect("Should create all the missing folders");
            }
            File::create(&path).expect("Should create a file");
        }
        fs::write(&*path, "test change").unwrap();
        let enough_time_to_wait_changes = 200;
        std::thread::sleep(Duration::from_millis(enough_time_to_wait_changes));
        let changes = backend.take_changes();
        assert!(changes.is_ok(), "Changes should be taken without errors: {:?}", changes.err());
        if let Ok(changes) = changes {
            assert_eq!(changes.len(), 0, "There should no changes")
        }
    }

    fn create_instrument_and_phrase(
        backend: &mut Backend,
        instrument_id: usize,
        phrase_id: usize,
        instrument_index: u8,
        instrument_name: &str,
        phrase_index: u8,
        phrase_name: &str,
    ) -> (InstrumentId, PhraseId) {
        let instrument_id = InstrumentId::from(instrument_id);
        backend.set_new_instrument_indexes(vec![(
            instrument_id,
            InstrumentIndex::try_from(instrument_index).unwrap(),
        )]);
        let phrase_id = PhraseId::from(phrase_id);
        backend.set_new_phrase_indexes(
            instrument_id,
            vec![(phrase_id, PhraseIndex::try_from(phrase_index).unwrap())],
        );
        let _ = backend.register_script(
            instrument_id,
            instrument_name,
            phrase_id,
            phrase_name,
            Some("ScriptBody"),
        );
        (instrument_id, phrase_id)
    }

    #[test]
    fn register_phrase_with_unknown_instrument() {
        let (_tmp_dir, song_path, mut backend) = setup("filename.xrns");
        let result = backend.register_script(
            InstrumentId::try_from(3).unwrap(),
            "Piano",
            PhraseId::try_from(2).unwrap(),
            "Intro",
            Some(""),
        );
        assert!(result.is_err());
        let error_message = result.unwrap_err().to_string();
        assert_eq!(error_message, "There is no instrument 3");

        let new_path = song_path
            .with_extension("")
            .join("lua-scripts")
            .join("003-Piano")
            .join("002-Intro.lua");
        test_no_changes(&mut backend, Rc::from(new_path));
    }

    #[test]
    fn register_phrase_with_known_instrument_and_unknown_phrase_id() {
        let (_tmp_dir, _song_path, mut backend) = setup("filename.xrns");
        let instrument_id = InstrumentId::from(3);
        backend.set_new_instrument_indexes(vec![(
            instrument_id,
            InstrumentIndex::try_from(1).unwrap(),
        )]);
        let result = backend.register_script(
            instrument_id,
            "Piano",
            PhraseId::try_from(2).unwrap(),
            "Intro",
            Some(""),
        );
        assert!(result.is_err());
        let error_message = result.unwrap_err().to_string();
        assert_eq!(error_message, "There is no phrase 2 for instrument 3");
    }

    #[test]
    fn register_phrase_successfully() {
        let (_tmp_dir, _song_path, mut backend) = setup("filename.xrns");
        let instrument_id = InstrumentId::from(3);
        backend.set_new_instrument_indexes(vec![(
            instrument_id,
            InstrumentIndex::try_from(1).unwrap(),
        )]);
        let phrase_id = PhraseId::from(2);
        backend.set_new_phrase_indexes(
            instrument_id,
            vec![(phrase_id, PhraseIndex::try_from(1).unwrap())],
        );
        let result =
            backend.register_script(instrument_id, "Piano", phrase_id, "Intro", Some("ScriptBody"));
        assert!(result.is_ok(), "register_script should return OK, {:?}", result.err());
        let script_path = result.unwrap();
        test_take_changes(&mut backend, script_path.into());

        let script_path_result = backend.unregister_script(instrument_id, phrase_id);
        assert!(
            script_path_result.is_ok(),
            "unregister_script should return OK, {:?}",
            script_path_result.err()
        );
        let script_path = script_path_result.unwrap();
        assert_eq!(script_path.clone().extension().unwrap(), "bak");
    }

    #[test]
    fn update_song_path() {
        let (tmp_dir, song_path, mut backend) = setup("filename.xrns");

        let instrument_id = InstrumentId::from(3);
        let instrument_index = InstrumentIndex::try_from(1).unwrap();
        backend.set_new_instrument_indexes(vec![(instrument_id, instrument_index)]);

        let phrase_id = PhraseId::from(2);
        let phrase_index = PhraseIndex::try_from(1).unwrap();
        backend.set_new_phrase_indexes(instrument_id, vec![(phrase_id, phrase_index)]);

        let _ =
            backend.register_script(instrument_id, "Piano", phrase_id, "Intro", Some("ScriptBody"));
        let old_phrase_path = backend
            .script_path_registry
            .get_path(instrument_index, phrase_index)
            .unwrap()
            .to_owned();

        let old_song_path = backend.script_path_registry.get_song_path().to_owned();
        let new_song_path = tmp_dir.path().join("new_filename.xrns");
        let result = backend.update_song_path(new_song_path.as_path());

        assert!(result.is_ok(), "update_song_path should return OK, {:?}", result.err());

        let new_phrase_path =
            backend.script_path_registry.get_path(instrument_index, phrase_index).unwrap();
        println!("New phrase path  = {:?}", new_phrase_path);
        assert!(old_phrase_path.exists(), "Old phrase should also exist");
        assert!(new_phrase_path.exists(), "New phrase path should exist");

        test_take_changes(&mut backend, new_phrase_path.into());
    }

    #[test]
    fn rename_script() {
        let song_name = "filename.xrns";
        let (tmp_dir, _song_path, mut backend) = setup(song_name);
        let instrument_id = InstrumentId::from(1);
        backend.set_new_instrument_indexes(vec![(
            instrument_id,
            InstrumentIndex::try_from(1).unwrap(),
        )]);
        let phrase_id = PhraseId::from(2);
        backend.set_new_phrase_indexes(
            instrument_id,
            vec![(phrase_id, PhraseIndex::try_from(1).unwrap())],
        );
        let _ =
            backend.register_script(instrument_id, "Piano", phrase_id, "Intro", Some("ScriptBody"));

        let old_path = tmp_dir
            .path()
            .join(song_name)
            .with_extension("")
            .join("lua-scripts")
            .join("001-Piano")
            .join("001-Intro.lua");
        assert!(old_path.exists());

        let result = backend.rename_script(instrument_id, phrase_id, "Intro/Part1");
        assert!(result.is_ok(), "rename_script should return OK, {:?}", result.err());

        assert!(!old_path.exists());
        let new_path = tmp_dir
            .path()
            .join(song_name)
            .with_extension("")
            .join("lua-scripts")
            .join("001-Piano")
            .join("001-Intro-Part1.lua");
        assert!(new_path.exists());

        test_take_changes(&mut backend, new_path.into());
    }

    #[test]
    fn rename_script_should_not_fail_when_the_same_path() {
        let (_tmp_dir, _song_path, mut backend) = setup("filename.xrns");
        let (instrument_id, phrase_id) =
            create_instrument_and_phrase(&mut backend, 1, 1, 1, "Piano", 1, "Intro/Part1");
        let result = backend.rename_script(instrument_id, phrase_id, "Intro-Part1");
        assert!(result.is_ok(), "rename_script should return OK, {:?}", result.err());
    }

    #[test]
    fn rename_instrument() {
        let song_name = "filename.xrns";
        let (tmp_dir, song_path, mut backend) = setup(song_name);
        let (instrument_id, _) =
            create_instrument_and_phrase(&mut backend, 1, 1, 1, "Piano", 1, "Intro/Part1");

        let lua_scripts_path =
            tmp_dir.path().join(&song_path).with_extension("").join("lua-scripts");
        let old_instrument_path = lua_scripts_path.join("001-Piano");
        let old_phrase_path = old_instrument_path.join("001-Intro-Part1.lua");

        assert!(old_instrument_path.exists(), "Old instrument path should exist before rename");
        assert!(old_phrase_path.exists(), "Old phrase path should exist before rename");

        let original_content = fs::read_to_string(&old_phrase_path).unwrap();
        assert_eq!(original_content, "ScriptBody", "Original content should match");

        let result = backend.rename_instrument(instrument_id, "Viola");
        assert!(result.is_ok(), "rename_instrument should return OK, {:?}", result.err());

        assert!(!old_instrument_path.exists(), "Old instrument path should not exist after rename");
        assert!(!old_phrase_path.exists(), "Old phrase path should not exist after rename");

        let new_instrument_path = lua_scripts_path.join("001-Viola");
        let new_phrase_path = new_instrument_path.join("001-Intro-Part1.lua");
        assert!(new_instrument_path.exists(), "New instrument path should exist after rename");
        assert!(new_phrase_path.exists(), "New phrase path should exist after rename");

        let new_content = fs::read_to_string(&new_phrase_path).unwrap();
        assert_eq!(new_content, original_content, "Content should be preserved after rename");

        let instrument_bak_path = lua_scripts_path.join("001-Piano.bak");
        let phrase_bak_path = old_instrument_path.with_extension("bak").join("001-Intro-Part1.bak");
        assert!(phrase_bak_path.exists(), "Phrase bak file should exist");

        assert!(
            instrument_bak_path.exists(),
            "Instrument backup directory should exist at {:?}",
            instrument_bak_path
        );

        let phrase_bak_inside_instrument =
            lua_scripts_path.join("001-Piano.bak").join("001-Intro-Part1.bak");
        assert!(
            phrase_bak_inside_instrument.exists(),
            "Phrase backup file should exist at {:?}",
            phrase_bak_inside_instrument
        );

        let backup_content = fs::read_to_string(&phrase_bak_inside_instrument).unwrap();
        assert_eq!(
            backup_content, original_content,
            "Backup content should match original content"
        );

        test_take_changes(&mut backend, new_phrase_path.into());
    }

    #[test]
    fn make_backup_path() {
        let tmp_dir = TempDir::new().unwrap();
        let song_path = tmp_dir.path().join("filename.xrns");
        fs::write(song_path.as_path(), "some test").unwrap();
        let backup_path = Backend::make_backup_path(song_path.as_path(), "xrns.bak");
        fs::rename(song_path.as_path(), backup_path.as_path()).unwrap();
        assert!(backup_path.ends_with("filename.xrns.bak"));

        fs::write(song_path.as_path(), "some test2").unwrap();
        let backup_path = Backend::make_backup_path(song_path.as_path(), "xrns.bak");
        assert!(backup_path.to_str().unwrap().ends_with("filename.xrns.bak1"));
    }

    #[test]
    fn unregister_instrument() {
        let song_name = "filename.xrns";
        let (tmp_dir, song_path, mut backend) = setup(song_name);
        let (instrument_id, _) =
            create_instrument_and_phrase(&mut backend, 1, 1, 1, "Piano", 1, "Intro/Part1");
        let old_path =
            tmp_dir.path().join(song_path).with_extension("").join("lua-scripts").join("001-Piano");
        assert!(old_path.exists());

        let phrase_path = tmp_dir
            .path()
            .join(song_name)
            .with_extension("")
            .join("lua-scripts")
            .join("001-Piano")
            .join("001-Intro-Part1.lua");
        test_take_changes(&mut backend, phrase_path.clone().into());

        let result = backend.unregister_instrument(instrument_id);
        assert!(result.is_ok(), "unregister_instrument should return OK, {:?}", result.err());

        assert!(!old_path.exists());
        let new_path = tmp_dir
            .path()
            .join(song_name)
            .with_extension("")
            .join("lua-scripts")
            .join("001-Piano.bak");
        assert!(new_path.exists());

        test_no_changes(&mut backend, phrase_path.into());
    }
}
