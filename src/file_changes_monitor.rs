use anyhow::Result;
use notify_debouncer_mini::notify::{RecommendedWatcher, RecursiveMode};
use notify_debouncer_mini::{new_debouncer, DebounceEventResult, Debouncer};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

#[derive(Debug, PartialEq)]
pub struct Change {
    pub path: PathBuf,
    pub text: String,
}
pub struct FileChangesMonitor {
    debouncer: Debouncer<RecommendedWatcher>,
    changes: Arc<Mutex<Vec<Change>>>,
}
impl FileChangesMonitor {
    pub fn new(duration: Duration) -> Self {
        let changes = Arc::new(Mutex::new(vec![]));
        let changes_for_watcher = Arc::clone(&changes);

        let debouncer = new_debouncer(duration, move |res: DebounceEventResult| match res {
            Ok(events) => {
                let mut new_changes: Vec<Change> = Vec::with_capacity(events.len());
                for event in events {
                    if let Ok(text) = fs::read_to_string(&event.path) {
                        new_changes.push(Change { path: event.path.clone(), text });
                    }
                }
                // TODO: consider using parking_lot
                changes_for_watcher.lock().unwrap().append(&mut new_changes);
            }
            Err(e) => {
                eprintln!("File watch error: {:?}", e);
            }
        })
        .unwrap(); // TODO: we should handle these errors

        FileChangesMonitor { debouncer, changes }
    }

    pub fn watch_file(&mut self, path: &Path) -> Result<()> {
        self.debouncer.watcher().watch(path, RecursiveMode::NonRecursive)?;
        Ok(())
    }

    pub fn unwatch_file(&mut self, path: &Path) -> Result<()> {
        if let Ok(mut changes) = self.changes.lock() {
            let _ = changes.extract_if(.., |change| change.path == path);
            self.debouncer.watcher().unwatch(path)?
        }
        Ok(())
    }

    pub fn take_changes(&mut self) -> Vec<Change> {
        match self.changes.lock() {
            Ok(mut changes) => changes.drain(..).collect(),
            Err(_) => vec![],
        }
    }

    // TODO: it should return Result
    // TODO: code duplication
    pub fn load_file(&mut self, path: &Path) {
        if let Ok(text) = fs::read_to_string(path) {
            if let Ok(mut changes) = self.changes.lock() {
                changes.push(Change { path: path.to_path_buf(), text });
            }
        }
    }
}

#[cfg(test)]
mod test {
    use crate::file_changes_monitor::{Change, FileChangesMonitor};
    use std::fs::OpenOptions;
    use std::io::Write;
    use std::path::{Path, PathBuf};
    use std::thread;
    use std::time::Duration;
    use tempfile::NamedTempFile;
    const TEXT_TO_APPEND: &str = "text_to_append";

    #[test]
    fn file_monitor_detects_changes() {
        let temp_path_guard = NamedTempFile::new().unwrap().into_temp_path();
        let temp_path: PathBuf = temp_path_guard.canonicalize().unwrap();

        let mut file_monitor = FileChangesMonitor::new(Duration::from_millis(10));
        let watch_result = file_monitor.watch_file(temp_path.as_path());
        assert!(watch_result.is_ok(), "watch_file should return OK, {:?}", watch_result.err());

        append_to_file(&temp_path);
        thread::sleep(Duration::from_millis(100));

        let changes = file_monitor.take_changes();
        assert_eq!(
            [Change { path: temp_path.clone(), text: TEXT_TO_APPEND.to_string() }],
            *changes
        );

        let unwatch_result = file_monitor.unwatch_file(temp_path.as_path());
        assert!(
            unwatch_result.is_ok(),
            "unwatch_file should return OK, {:?}",
            unwatch_result.err()
        );

        append_to_file(&temp_path);
        thread::sleep(Duration::from_millis(100));

        let changes = file_monitor.take_changes();
        assert!(changes.is_empty());
    }

    // TODO: return io::Result<()>
    fn append_to_file(temp_path: &Path) {
        let mut file = OpenOptions::new().append(true).open(temp_path).unwrap();
        write!(file, "{}", TEXT_TO_APPEND).unwrap();
    }
}
