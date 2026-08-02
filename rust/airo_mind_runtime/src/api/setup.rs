//! Installation. The only place a model file name is legitimate.
//!
//! `ADR-0018 §4` says nothing above the Model Manager names a file, a
//! quantisation or a runtime. Installing is the exception the rule needs: to
//! put a bundled asset on disk, something has to know what it is called.
//!
//! Kept apart from `mind` so the Meeting capability's surface stays the
//! capability's, and so that the day a second capability ships, installation is
//! not something it has to reach through a meeting to reach.

use crate::models;

/// A file the app must have on disk before anything can resolve.
pub struct RequiredModel {
    pub file_name: String,
    pub size_bytes: u64,
    /// Pinned in source (`ADR-0018 §2`). A digest read from a file beside the
    /// model is a digest whoever replaced the model also controls.
    pub sha256: String,
}

/// What a model looks like right now.
pub struct InstalledModel {
    pub file_name: String,
    pub present: bool,
    /// Only meaningful when `present`. False means the bytes on disk are not
    /// the bytes that were pinned.
    pub verified: bool,
    pub detail: String,
}

/// Everything Milestone 2 bundles.
pub fn required_models() -> Vec<RequiredModel> {
    models::required_files()
        .into_iter()
        .map(|(file_name, size_bytes, sha256)| RequiredModel {
            file_name,
            size_bytes,
            sha256,
        })
        .collect()
}

/// Full verification of what is installed.
///
/// Hashes every file, so it is **not** on the launch path — half a gigabyte is
/// about a second. Called after an install, and available to a user who wants
/// to check. `resolve` does the cheap size check on every launch instead; that
/// trade is stated where it is made, in `models::resolve`.
pub fn verify_installed_models(models_dir: String) -> Vec<InstalledModel> {
    let dir = std::path::Path::new(&models_dir);

    required_models()
        .into_iter()
        .map(|required| {
            let path = dir.join(&required.file_name);
            let Ok(metadata) = std::fs::metadata(&path) else {
                return InstalledModel {
                    file_name: required.file_name,
                    present: false,
                    verified: false,
                    detail: "not installed".into(),
                };
            };
            if metadata.len() != required.size_bytes {
                return InstalledModel {
                    file_name: required.file_name,
                    present: true,
                    verified: false,
                    detail: format!(
                        "{} bytes on disk, {} expected",
                        metadata.len(),
                        required.size_bytes
                    ),
                };
            }
            match crate::digest_file(&path) {
                Ok(found) if found == required.sha256 => InstalledModel {
                    file_name: required.file_name,
                    present: true,
                    verified: true,
                    detail: "verified".into(),
                },
                Ok(found) => InstalledModel {
                    file_name: required.file_name,
                    present: true,
                    verified: false,
                    detail: format!("digest {found}"),
                },
                Err(e) => InstalledModel {
                    file_name: required.file_name,
                    present: true,
                    verified: false,
                    detail: format!("unreadable: {e}"),
                },
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_required_model_carries_a_pinned_digest_and_a_size() {
        let required = required_models();
        assert!(
            !required.is_empty(),
            "nothing to install is not a valid state"
        );
        for model in &required {
            assert_eq!(model.sha256.len(), 64, "{} is unpinned", model.file_name);
            assert!(model.size_bytes > 0, "{} has no size", model.file_name);
        }
    }

    #[test]
    fn an_empty_directory_reports_every_model_as_absent() {
        let dir = std::env::temp_dir().join(format!("airo_setup_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        let statuses = verify_installed_models(dir.to_string_lossy().into_owned());
        assert_eq!(statuses.len(), required_models().len());
        assert!(statuses.iter().all(|s| !s.present && !s.verified));
        assert!(statuses.iter().all(|s| s.detail == "not installed"));
    }

    /// A file of the right name and the wrong contents must report present and
    /// unverified -- the two facts a user needs to know they should reinstall.
    #[test]
    fn a_wrong_file_is_present_but_not_verified() {
        let dir = std::env::temp_dir().join(format!("airo_setup_bad_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        let first = required_models().remove(0);
        std::fs::write(dir.join(&first.file_name), b"not a model").unwrap();

        let statuses = verify_installed_models(dir.to_string_lossy().into_owned());
        let status = statuses
            .iter()
            .find(|s| s.file_name == first.file_name)
            .unwrap();
        assert!(status.present);
        assert!(!status.verified);
        assert!(status.detail.contains("bytes on disk"), "{}", status.detail);
    }
}
