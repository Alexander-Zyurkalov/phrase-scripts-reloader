use anyhow::{anyhow, Result};
use std::fmt;
use std::fmt::Formatter;

const MIN_INSTRUMENT_INDEX: i64 = 1;
const MAX_INSTRUMENT_INDEX: i64 = 126;

const MIN_PHRASE_INDEX: i64 = 1;
const MAX_PHRASE_INDEX: i64 = 126;

fn validate_index(value: i64, min: i64, max: i64) -> Result<u8> {
    if value > max {
        return Err(anyhow!(
            "The value is bigger than {}, it should be within {}..{}",
            max,
            min,
            max
        ));
    }
    if value < min {
        return Err(anyhow!(
            "The value is less than {}, it should be within {}..{}",
            min,
            min,
            max
        ));
    }
    Ok(value as u8)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct InstrumentIndex(u8);

// TODO: Better to have simple error structs for simple datatypes
// #[derive(Debug)]
// struct InvalidIndex;
// impl fmt::Display for InvalidIndex { ...
//     impl std::error::Error for InvalidIndex {}

impl TryFrom<i64> for InstrumentIndex {
    type Error = anyhow::Error;
    fn try_from(value: i64) -> Result<InstrumentIndex> {
        Ok(InstrumentIndex(validate_index(value, MIN_INSTRUMENT_INDEX, MAX_INSTRUMENT_INDEX)?))
    }
}

impl fmt::Display for InstrumentIndex {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{:03}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PhraseIndex(u8);

impl TryFrom<i64> for PhraseIndex {
    type Error = anyhow::Error;
    fn try_from(value: i64) -> Result<PhraseIndex> {
        Ok(PhraseIndex(validate_index(value, MIN_PHRASE_INDEX, MAX_PHRASE_INDEX)?))
    }
}

impl fmt::Display for PhraseIndex {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{:03}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct InstrumentId(usize);

impl From<i64> for InstrumentId {
    fn from(value: i64) -> Self {
        InstrumentId(value as usize)
    }
}

impl From<InstrumentId> for i64 {
    fn from(value: InstrumentId) -> Self {
        value.0 as i64
    }
}

impl fmt::Display for InstrumentId {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PhraseId(usize);

impl From<i64> for PhraseId {
    fn from(value: i64) -> Self {
        PhraseId(value as usize)
    }
}

impl From<PhraseId> for i64 {
    fn from(value: PhraseId) -> Self {
        value.0 as i64
    }
}

impl fmt::Display for PhraseId {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[test]
fn instrument_index_test() {
    assert_eq!(InstrumentIndex::try_from(10).unwrap().0, 10);
    assert!(InstrumentIndex::try_from(127).is_err());
    assert!(InstrumentIndex::try_from(0).is_err());
}

#[test]
fn phrase_index_test() {
    assert_eq!(PhraseIndex::try_from(10).unwrap().0, 10);
    assert!(PhraseIndex::try_from(127).is_err());
    assert!(PhraseIndex::try_from(0).is_err());
}
