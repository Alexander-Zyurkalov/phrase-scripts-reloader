use std::fmt;
use std::fmt::Formatter;
use anyhow::{anyhow, Result};

const MIN_INSTRUMENT_INDEX: u8 = 1;
const MAX_INSTRUMENT_INDEX: u8 = 126;

const MIN_PHRASE_INDEX: u8 = 1;
const MAX_PHRASE_INDEX: u8 = 126;

fn validate_index(value: u8, min: u8, max: u8) -> Result<u8> {
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
    Ok(value)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct InstrumentIndex(u8);

impl TryFrom<u8> for InstrumentIndex {
    type Error = anyhow::Error;
    fn try_from(value: u8) -> Result<InstrumentIndex> {
        Ok(InstrumentIndex(validate_index(
            value,
            MIN_INSTRUMENT_INDEX,
            MAX_INSTRUMENT_INDEX,
        )?))
    }
}

impl fmt::Display for InstrumentIndex {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{:03}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PhraseIndex(u8);

impl TryFrom<u8> for PhraseIndex {
    type Error = anyhow::Error;
    fn try_from(value: u8) -> Result<PhraseIndex> {
        Ok(PhraseIndex(validate_index(
            value,
            MIN_PHRASE_INDEX,
            MAX_PHRASE_INDEX,
        )?))
    }
}

impl fmt::Display for PhraseIndex {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{:03}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct InstrumentId(usize);

impl From<usize> for InstrumentId {
    fn from(value: usize) -> Self {
        InstrumentId(value)
    }
}

impl fmt::Display for InstrumentId {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PhraseId(usize);

impl From<usize> for PhraseId {
    fn from(value: usize) -> Self {
        PhraseId(value)
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