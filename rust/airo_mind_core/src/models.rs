//! The Model Manager. `ADR-0018`, the part Milestone 2 needs.
//!
//! # Availability is a query, not a side effect
//!
//! `ADR-0018 §1`: the runtime asks for a **capability** — a task, a budget, a
//! minimum quality — and gets back a handle or a structured [`ModelUnavailable`]
//! naming what was missing. It never initiates a download and it never
//! distinguishes bundled from imported from downloaded.
//!
//! That inversion is what keeps *"never cloud required"* true in code rather
//! than in positioning, and it is why `ModelUnavailable` is an ordinary result
//! on an ordinary path rather than an error to log and swallow.
//!
//! # Bundled only, on purpose
//!
//! `ADR-0018 §7`: *"Milestone 2 ships bundled models. Import and download can
//! follow; the sequence matters because bundling is the only strategy that
//! proves the offline claim."* [`AcquisitionStrategy`] carries the other two so
//! the verification difference is written down where it will be read — an
//! imported model has **no signature to check**, and conflating that with a
//! downloaded one is the mistake §2 exists to prevent.
//!
//! # Not the Vault's revocation ledger
//!
//! `ADR-0018 §6`: model revocation is asset lifecycle. Sharing the Vault's
//! ledger would put application assets into the structure whose growth
//! `ADR-0017` spent a revision bounding.

use std::path::{Path, PathBuf};

use crate::digest::file_digest;

/// What a capability needs done. Not which file it wants.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModelTask {
    Speech,
    Generation,
}

/// `ADR-0018 §1`'s `minimum_quality`. Ordered worst to best.
///
/// Milestone 2 bundles one tier. The other two are declared because a caller
/// must be able to express "Draft is not good enough" today, so that shipping a
/// better model later is a registry row rather than an API change.
#[allow(dead_code)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ModelQuality {
    Draft,
    Standard,
    High,
}

/// `ADR-0018 §2`. Present in full because the three are **not** interchangeable
/// and their verification must not be conflated.
#[allow(dead_code)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AcquisitionStrategy {
    /// Ships with the app. Digest pinned in source.
    Bundled,
    /// User-supplied. Digest recorded on import; there is no signature to
    /// check, and pretending otherwise is the §2 mistake.
    Imported,
    /// Fetched from a configured source. Signature **and** pinned digest.
    Downloaded,
}

/// A capability's request.
pub struct ModelRequirement {
    pub task: ModelTask,
    pub memory_budget_mb: u32,
    pub minimum_quality: ModelQuality,
}

/// Why no model could be resolved. Every variant names something actionable —
/// `ADR-0018 §1` requires the caller to be able to degrade, prompt or decline.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ModelUnavailable {
    /// Nothing in the registry serves this task at this quality at all.
    NoModelForTask,
    /// A model exists but the device cannot afford it.
    OverBudget { needs_mb: u32, budget_mb: u32 },
    /// Known, affordable, and not on disk. The commonest first-run state.
    NotInstalled {
        logical_id: String,
        file_name: String,
    },
    /// On disk and **not what was pinned**. Corruption, a truncated copy, or a
    /// substituted file — all three mean the same thing: do not load it.
    DigestMismatch { logical_id: String, found: String },
    /// `ADR-0018 §6`. Bad weights, a vulnerability, a withdrawn licence.
    Revoked { logical_id: String, reason: String },
}

impl std::fmt::Display for ModelUnavailable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoModelForTask => write!(f, "no model serves that task"),
            Self::OverBudget {
                needs_mb,
                budget_mb,
            } => write!(f, "model needs {needs_mb} MB, budget is {budget_mb} MB"),
            Self::NotInstalled {
                logical_id,
                file_name,
            } => write!(f, "{logical_id} is not installed (expected {file_name})"),
            Self::DigestMismatch { logical_id, found } => {
                write!(f, "{logical_id} does not match its pinned digest ({found})")
            }
            Self::Revoked { logical_id, reason } => {
                write!(f, "{logical_id} has been revoked: {reason}")
            }
        }
    }
}

impl std::error::Error for ModelUnavailable {}

/// A model that resolved.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResolvedModel {
    /// `ADR-0018 §4`: the **logical** identity, which is what gets recorded
    /// with generated content. Never the file name.
    pub logical_id: String,
    pub version: String,
    pub path: String,
    pub memory_mb: u32,
    pub strategy: AcquisitionStrategy,
}

/// A registry entry. Static because a bundled model's digest is pinned **in
/// source** (`ADR-0018 §2`) — a digest read from a file beside the model is a
/// digest an attacker who replaced the model also controls.
struct Bundled {
    logical_id: &'static str,
    version: &'static str,
    task: ModelTask,
    quality: ModelQuality,
    file_name: &'static str,
    /// Admission cost, not file size. What the Supervisor charges the budget.
    memory_mb: u32,
    size_bytes: u64,
    sha256: &'static str,
}

/// Everything Milestone 2 ships.
///
/// `ADR-0018 §5`: an update installs a new logical version alongside the old
/// and switches resolution. Adding a row is how that happens; nothing rewrites
/// a model file in place.
const REGISTRY: &[Bundled] = &[
    Bundled {
        logical_id: "airo.speech.compact",
        version: "1",
        task: ModelTask::Speech,
        quality: ModelQuality::Draft,
        file_name: "ggml-tiny.en.bin",
        memory_mb: 512,
        size_bytes: 77_704_715,
        sha256: "921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f",
    },
    Bundled {
        logical_id: "airo.generation.compact",
        version: "1",
        task: ModelTask::Generation,
        quality: ModelQuality::Draft,
        file_name: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
        memory_mb: 1024,
        size_bytes: 491_400_032,
        sha256: "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db",
    },
];

/// Resolves a requirement against what is installed.
///
/// `verify_digest` is the caller's call because the cost is not small: hashing
/// half a gigabyte takes about a second, which is fine on install and not fine
/// on every launch. The honest statement is that a full verification happens
/// when a model is installed, and a launch checks the cheap invariant — that
/// the file is still exactly the size that was pinned. A substitution that also
/// matches the byte count survives that check until the next install-time
/// verification, and that is the trade being made, not an oversight.
pub fn resolve(
    requirement: &ModelRequirement,
    models_dir: &Path,
    revocations: &[(String, String)],
    verify_digest: bool,
) -> Result<ResolvedModel, ModelUnavailable> {
    let mut best: Option<&Bundled> = None;
    let mut over_budget: Option<&Bundled> = None;

    for entry in REGISTRY {
        if entry.task != requirement.task || entry.quality < requirement.minimum_quality {
            continue;
        }
        if entry.memory_mb > requirement.memory_budget_mb {
            // Remembered so the caller learns "too big for this device" rather
            // than "no such model", which are different problems.
            over_budget.get_or_insert(entry);
            continue;
        }
        // Highest quality that fits.
        if best.is_none_or(|b| entry.quality > b.quality) {
            best = Some(entry);
        }
    }

    let entry = match (best, over_budget) {
        (Some(entry), _) => entry,
        (None, Some(big)) => {
            return Err(ModelUnavailable::OverBudget {
                needs_mb: big.memory_mb,
                budget_mb: requirement.memory_budget_mb,
            })
        }
        (None, None) => return Err(ModelUnavailable::NoModelForTask),
    };

    if let Some((_, reason)) = revocations.iter().find(|(id, _)| id == entry.logical_id) {
        return Err(ModelUnavailable::Revoked {
            logical_id: entry.logical_id.to_string(),
            reason: reason.clone(),
        });
    }

    let path: PathBuf = models_dir.join(entry.file_name);
    let metadata = std::fs::metadata(&path).map_err(|_| ModelUnavailable::NotInstalled {
        logical_id: entry.logical_id.to_string(),
        file_name: entry.file_name.to_string(),
    })?;

    // A truncated download is the common corruption and it is free to detect.
    if metadata.len() != entry.size_bytes {
        return Err(ModelUnavailable::DigestMismatch {
            logical_id: entry.logical_id.to_string(),
            found: format!("{} bytes, expected {}", metadata.len(), entry.size_bytes),
        });
    }

    if verify_digest {
        let found = file_digest(&path).map_err(|e| ModelUnavailable::DigestMismatch {
            logical_id: entry.logical_id.to_string(),
            found: format!("unreadable: {e}"),
        })?;
        if found != entry.sha256 {
            return Err(ModelUnavailable::DigestMismatch {
                logical_id: entry.logical_id.to_string(),
                found,
            });
        }
    }

    Ok(ResolvedModel {
        logical_id: entry.logical_id.to_string(),
        version: entry.version.to_string(),
        path: path.to_string_lossy().into_owned(),
        memory_mb: entry.memory_mb,
        strategy: AcquisitionStrategy::Bundled,
    })
}

/// What the app must have on disk. Named by **file**, because installing is the
/// one place a file name is legitimate — everything above the Manager names a
/// logical model (`ADR-0018 §4`).
pub fn required_files() -> Vec<(String, u64, String)> {
    REGISTRY
        .iter()
        .map(|e| (e.file_name.to_string(), e.size_bytes, e.sha256.to_string()))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dir(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("airo_models_{name}_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn install(dir: &Path, entry: &Bundled, bytes: u64) {
        std::fs::write(dir.join(entry.file_name), vec![0u8; bytes as usize]).unwrap();
    }

    fn speech(budget: u32) -> ModelRequirement {
        ModelRequirement {
            task: ModelTask::Speech,
            memory_budget_mb: budget,
            minimum_quality: ModelQuality::Draft,
        }
    }

    /// The first-run state, and the one `ADR-0018 §7` says the product must be
    /// able to explain.
    #[test]
    fn nothing_installed_names_what_is_missing() {
        let d = dir("empty");
        let err = resolve(&speech(4096), &d, &[], false).unwrap_err();
        assert_eq!(
            err,
            ModelUnavailable::NotInstalled {
                logical_id: "airo.speech.compact".into(),
                file_name: "ggml-tiny.en.bin".into(),
            }
        );
    }

    #[test]
    fn an_installed_model_resolves_to_its_logical_identity() {
        let d = dir("ok");
        install(&d, &REGISTRY[0], REGISTRY[0].size_bytes);

        let resolved = resolve(&speech(4096), &d, &[], false).unwrap();
        assert_eq!(resolved.logical_id, "airo.speech.compact");
        assert_eq!(resolved.version, "1");
        assert_eq!(resolved.strategy, AcquisitionStrategy::Bundled);
        // ADR-0018 §4: nothing above the Manager names a file, but the Manager
        // must still hand one over.
        assert!(resolved.path.ends_with("ggml-tiny.en.bin"));
    }

    /// "Too big for this device" and "no such model" are different problems
    /// with different fixes, and the caller must be able to tell them apart.
    #[test]
    fn a_model_that_does_not_fit_says_so_rather_than_saying_it_is_missing() {
        let d = dir("budget");
        install(&d, &REGISTRY[0], REGISTRY[0].size_bytes);

        let err = resolve(&speech(64), &d, &[], false).unwrap_err();
        assert_eq!(
            err,
            ModelUnavailable::OverBudget {
                needs_mb: 512,
                budget_mb: 64
            }
        );
    }

    #[test]
    fn a_quality_nothing_provides_is_no_model_for_the_task() {
        let d = dir("quality");
        install(&d, &REGISTRY[0], REGISTRY[0].size_bytes);

        let err = resolve(
            &ModelRequirement {
                task: ModelTask::Speech,
                memory_budget_mb: 4096,
                minimum_quality: ModelQuality::High,
            },
            &d,
            &[],
            false,
        )
        .unwrap_err();
        assert_eq!(err, ModelUnavailable::NoModelForTask);
    }

    /// A truncated copy is the common corruption. Catching it on size costs
    /// nothing and turns a confusing backend crash into a clear message.
    #[test]
    fn a_truncated_model_is_refused_before_any_hashing() {
        let d = dir("truncated");
        install(&d, &REGISTRY[0], 1024);

        let err = resolve(&speech(4096), &d, &[], false).unwrap_err();
        match err {
            ModelUnavailable::DigestMismatch { logical_id, found } => {
                assert_eq!(logical_id, "airo.speech.compact");
                assert!(found.contains("1024 bytes"), "{found}");
            }
            other => panic!("expected a size mismatch, got {other:?}"),
        }
    }

    /// The whole point of pinning: a file of exactly the right length whose
    /// contents are not what shipped must still be refused.
    #[test]
    fn a_substituted_model_of_the_right_size_fails_verification() {
        let d = dir("substituted");
        install(&d, &REGISTRY[0], REGISTRY[0].size_bytes);

        // Passes without verification -- this is the trade `resolve` documents.
        assert!(resolve(&speech(4096), &d, &[], false).is_ok());

        let err = resolve(&speech(4096), &d, &[], true).unwrap_err();
        match err {
            ModelUnavailable::DigestMismatch { logical_id, found } => {
                assert_eq!(logical_id, "airo.speech.compact");
                assert_ne!(found, REGISTRY[0].sha256);
            }
            other => panic!("expected a digest mismatch, got {other:?}"),
        }
    }

    /// `ADR-0018 §6`. A revoked model is unavailable from the next resolution,
    /// even though the file is present and intact.
    #[test]
    fn a_revoked_model_is_unavailable_even_when_installed() {
        let d = dir("revoked");
        install(&d, &REGISTRY[0], REGISTRY[0].size_bytes);

        let revocations = vec![(
            "airo.speech.compact".to_string(),
            "withdrawn licence".to_string(),
        )];
        let err = resolve(&speech(4096), &d, &revocations, false).unwrap_err();
        assert_eq!(
            err,
            ModelUnavailable::Revoked {
                logical_id: "airo.speech.compact".into(),
                reason: "withdrawn licence".into(),
            }
        );
    }

    /// Revocation is checked before the file is, so a revoked model that is
    /// also missing still reports the revocation -- the reason the user needs.
    #[test]
    fn revocation_outranks_absence() {
        let d = dir("revoked-missing");
        let revocations = vec![("airo.speech.compact".to_string(), "bad weights".to_string())];
        assert!(matches!(
            resolve(&speech(4096), &d, &revocations, false),
            Err(ModelUnavailable::Revoked { .. })
        ));
    }

    #[test]
    fn every_registry_entry_pins_a_full_length_digest() {
        for entry in REGISTRY {
            assert_eq!(
                entry.sha256.len(),
                64,
                "{} has a malformed digest",
                entry.logical_id
            );
            assert!(entry.sha256.chars().all(|c| c.is_ascii_hexdigit()));
            assert!(entry.size_bytes > 0, "{} has no size", entry.logical_id);
        }
    }

    #[test]
    fn required_files_lists_everything_the_app_must_install() {
        let files = required_files();
        assert_eq!(files.len(), REGISTRY.len());
        assert!(files.iter().any(|(n, _, _)| n == "ggml-tiny.en.bin"));
    }
}
