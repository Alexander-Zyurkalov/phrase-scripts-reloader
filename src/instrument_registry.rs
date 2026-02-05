use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
use anyhow::{anyhow, Context, Result};
use std::collections::HashMap;
use std::rc::Rc;

#[derive(Debug)]
struct InstrumentMap {
    instrument_index: InstrumentIndex,
    phrase_indexes: HashMap<PhraseId, PhraseIndex>,
}

#[derive(Debug, Default)]
pub struct InstrumentRegistry {
    instrument_indexes: HashMap<InstrumentId, InstrumentMap>,
    instrument_names: HashMap<InstrumentId, Rc<str>>,
    phrase_names: HashMap<InstrumentId, HashMap<PhraseId, Rc<str>>>,
}

impl InstrumentRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get_indexes(
        &self,
        instrument_id: InstrumentId,
        phrase_id: PhraseId,
    ) -> Result<(InstrumentIndex, PhraseIndex)> {
        let instrument_map = self.get_instrument_map(instrument_id)?;
        let instrument_index = instrument_map.instrument_index;
        let phrase_index = *instrument_map
            .phrase_indexes
            .get(&phrase_id)
            .context(anyhow!(
                "There is no phrase {} for instrument {}",
                phrase_id,
                instrument_id
            ))?;
        Ok((instrument_index, phrase_index))
    }

    pub fn get_instrument_index(&self, instrument_id: InstrumentId) -> Result<InstrumentIndex> {
        let instrument_map = self.get_instrument_map(instrument_id)?;
        Ok(instrument_map.instrument_index)
    }

    pub fn get_instrument_name(&self, instrument_id: InstrumentId) -> Result<Rc<str>> {
        self.instrument_names
            .get(&instrument_id)
            .cloned()
            .context(anyhow!(
                "There is no name saved for this instrument: {}",
                instrument_id
            ))
    }

    pub fn get_phrase_name(
        &self,
        instrument_id: InstrumentId,
        phrase_id: PhraseId,
    ) -> Result<Rc<str>> {
        self.phrase_names
            .get(&instrument_id)
            .context(anyhow!("Can't find an instrument {}", instrument_id))?
            .get(&phrase_id)
            .cloned()
            .context(anyhow!(
                "Can't find a phrase for an instrument: {}.{}",
                instrument_id,
                phrase_id
            ))
    }
    pub fn get_all_instrument_ids(&self) -> Vec<InstrumentId> {
        self.instrument_indexes.keys().copied().collect()
    }

    pub fn get_all_phrase_ids(&self, instrument_id: InstrumentId) -> Vec<(PhraseId, PhraseIndex)> {
        self.instrument_indexes
            .get(&instrument_id)
            .map(|instrument_map| {
                instrument_map
                    .phrase_indexes
                    .iter()
                    .map(|(id, index)| (*id, *index))
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn set_instrument_indexes(
        &mut self,
        id_index_pairs: impl AsRef<[(InstrumentId, InstrumentIndex)]>,
    ) {
        for (instrument_id, instrument_index) in id_index_pairs.as_ref() {
            let instr_entry =
                self.instrument_indexes
                    .entry(*instrument_id)
                    .or_insert(InstrumentMap {
                        instrument_index: *instrument_index,
                        phrase_indexes: HashMap::default(),
                    });
            instr_entry.instrument_index = *instrument_index;
        }
    }

    pub fn set_phrase_indexes(
        &mut self,
        instrument_id: InstrumentId,
        id_index_pairs: impl AsRef<[(PhraseId, PhraseIndex)]>,
    ) {
        if let Some(instrument) = self.instrument_indexes.get_mut(&instrument_id) {
            for (phrase_id, phrase_index) in id_index_pairs.as_ref() {
                instrument
                    .phrase_indexes
                    .entry(*phrase_id)
                    .or_insert(*phrase_index);
            }
        }
    }

    // TODO: here is better to use &str instead of AsRef to prevent consuming
    pub fn set_instrument_name(&mut self, instrument_id: InstrumentId, name: impl AsRef<str>) {
        self.instrument_names
            .insert(instrument_id, Rc::from(name.as_ref()));
    }

    pub fn set_phrase_name(
        &mut self,
        instrument_id: InstrumentId,
        phrase_id: PhraseId,
        name: impl AsRef<str>,
    ) {
        let phrase_names = self.phrase_names.entry(instrument_id).or_default();
        phrase_names.insert(phrase_id, Rc::from(name.as_ref()));
    }

    pub fn remove_phrase_name(&mut self, instrument_id: InstrumentId, phrase_id: PhraseId) {
        if let Some(phrases) = self.phrase_names.get_mut(&instrument_id) {
            phrases.remove(&phrase_id);
        }
    }

    pub fn remove_instrument(&mut self, instrument_id: InstrumentId) {
        self.instrument_indexes.remove(&instrument_id);
        self.instrument_names.remove(&instrument_id);
        self.phrase_names.remove(&instrument_id);
    }

    fn get_instrument_map(&self, instrument_id: InstrumentId) -> Result<&InstrumentMap> {
        self.instrument_indexes
            .get(&instrument_id)
            .context(anyhow!("There is no instrument {}", instrument_id))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_registry_is_empty() {
        let registry = InstrumentRegistry::new();
        assert!(registry.instrument_indexes.is_empty());
        assert!(registry.instrument_names.is_empty());
        assert!(registry.phrase_names.is_empty());
    }

    #[test]
    fn test_set_and_get_instrument_index() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let instrument_index = InstrumentIndex::try_from(5).unwrap();

        registry.set_instrument_indexes(vec![(instrument_id, instrument_index)]);

        let result = registry.get_instrument_index(instrument_id);
        assert!(result.is_ok(), "get_instrument_index should return OK, {:?}", result.err());
        assert_eq!(result.unwrap(), instrument_index);
    }

    #[test]
    fn test_get_instrument_index_not_found() {
        let registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);

        let result = registry.get_instrument_index(instrument_id);
        assert!(result.is_err());
    }

    #[test]
    fn test_set_and_get_phrase_indexes() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let instrument_index = InstrumentIndex::try_from(1).unwrap();
        let phrase_id = PhraseId::from(2);
        let phrase_index = PhraseIndex::try_from(3).unwrap();

        registry.set_instrument_indexes(vec![(instrument_id, instrument_index)]);
        registry.set_phrase_indexes(instrument_id, vec![(phrase_id, phrase_index)]);

        let result = registry.get_indexes(instrument_id, phrase_id);
        assert!(result.is_ok(), "get_indexes should return OK, {:?}", result.err());
        let (got_instr_idx, got_phrase_idx) = result.unwrap();
        assert_eq!(got_instr_idx, instrument_index);
        assert_eq!(got_phrase_idx, phrase_index);
    }

    #[test]
    fn test_set_and_get_names() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let phrase_id = PhraseId::from(2);

        registry.set_instrument_name(instrument_id, "Piano");
        registry.set_phrase_name(instrument_id, phrase_id, "Intro");

        assert_eq!(
            &*registry.get_instrument_name(instrument_id).unwrap(),
            "Piano"
        );
        assert_eq!(
            &*registry.get_phrase_name(instrument_id, phrase_id).unwrap(),
            "Intro"
        );
    }

    #[test]
    fn test_remove_phrase_name() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let phrase_id = PhraseId::from(2);

        registry.set_phrase_name(instrument_id, phrase_id, "Intro");
        registry.remove_phrase_name(instrument_id, phrase_id);

        assert!(registry.get_phrase_name(instrument_id, phrase_id).is_err());
    }

    #[test]
    fn test_remove_instrument() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let instrument_index = InstrumentIndex::try_from(1).unwrap();

        registry.set_instrument_indexes(vec![(instrument_id, instrument_index)]);
        registry.set_instrument_name(instrument_id, "Piano");
        registry.set_phrase_name(instrument_id, PhraseId::from(1), "Intro");

        registry.remove_instrument(instrument_id);

        assert!(registry.get_instrument_index(instrument_id).is_err());
        assert!(registry.get_instrument_name(instrument_id).is_err());
        assert!(registry.get_all_phrase_ids(instrument_id).is_empty());
    }

    #[test]
    fn test_get_all_phrase_ids() {
        let mut registry = InstrumentRegistry::new();
        let instrument_id = InstrumentId::from(1);
        let instrument_index = InstrumentIndex::try_from(1).unwrap();

        registry.set_instrument_indexes(vec![(instrument_id, instrument_index)]);
        registry.set_phrase_indexes(
            instrument_id,
            vec![
                (PhraseId::from(1), PhraseIndex::try_from(1).unwrap()),
                (PhraseId::from(2), PhraseIndex::try_from(2).unwrap()),
            ],
        );

        let phrases = registry.get_all_phrase_ids(instrument_id);
        assert_eq!(phrases.len(), 2);
    }
}