//! Schema fingerprint + compatibility classes. `#1226`.
//!
//! ```text
//! Schema → canonical serialization → SHA-256 → schemaId
//! ```
//!
//! # Why this exists
//!
//! Issue text: *"Two devices must never hold different schemas for the same
//! data, and merge strategy must never change meaning underneath operations
//! already written."* [`ontology::EntityTypeDef`] (`#1223`) already declares
//! what a capability's entity type looks like; this module is what turns that
//! declaration into a value two devices can compare without trusting either
//! one's author to have bumped a version number honestly —
//! [`fingerprint`] is a stable hash over the type's structure, and
//! [`Compatibility`] classifies what changed between two fingerprinted
//! versions of the "same" type (same [`ontology::EntityTypeDef::name`] and
//! [`ontology::EntityTypeDef::extends`]).
//!
//! # The `#1223` seam this fills
//!
//! [`ontology::CoreEntityType::schema_id`] and
//! [`ontology::EntityTypeDef::schema_id`] already exist as stable, nameable
//! ids — deliberately *not* hashes, per their own doc comments. This module
//! does not change either method (existing callers and conformance tests
//! keep working unmodified); it adds the hash those ids were always missing,
//! joined to the name by [`schema_fingerprint_id`], and stored in
//! [`crate::runtime::Operation::schema_id`] instead of the bare name from now
//! on — the field [`crate::runtime::Operation`]'s own doc says was "empty
//! until a capability declares a real schema fingerprint (§5.5)".
//!
//! # What counts as compatible vs breaking
//!
//! [`classify`] compares two [`ontology::EntityTypeDef`]s that share a name
//! and `extends` (a name or `extends` change is not "the same type changing"
//! at all — it is [`Compatibility::Breaking`] by definition, "new lineage,
//! not a version bump" in the issue's own words):
//!
//! - **[`Compatibility::Compatible`]** — every property present in the old
//!   definition is present in the new one, unchanged in
//!   [`ontology::Primitive`]. Only additions are allowed. This is deliberately
//!   generous by the standard a schema with required/optional fields would
//!   use: [`ontology::EntityTypeDef::properties`] has no "required" flag —
//!   every property is populated by a `SetProperty` operation whenever a
//!   capability chooses to write it, never implied by the type declaration
//!   alone — so a newly declared property behaves exactly like an optional
//!   field on every entity written before it existed: absent, not wrong.
//! - **[`Compatibility::Breaking`]** — a property present in the old
//!   definition is missing from the new one (removed), or present in both
//!   with a different [`ontology::Primitive`] (retyped). Either one changes
//!   what an operation already on disk, written against the old shape,
//!   *means* when read under the new one — exactly what the issue's own
//!   `lww`→`manual` example calls out, generalized from merge strategy to the
//!   structural surface this crate actually has today (see the next section
//!   for why merge strategy itself isn't classified here).
//! - **[`Compatibility::CompatiblePlus`]** — defined so the three-class table
//!   the issue specifies is a complete, matchable enum (nothing downstream
//!   has to guess a fourth case exists), but [`classify`] never returns it
//!   yet. See "Honestly incomplete" below.
//!
//! # Honestly incomplete
//!
//! The issue's own worked example of a breaking change is a **merge
//! strategy** edit (`lww` → `manual` on a property), not a primitive
//! retype. [`ontology`]'s module doc already flags that per-property merge
//! overrides are not implemented (*"attaching the remaining policy fields is
//! follow-on work"*) — [`ontology::Primitive::default_merge`] is the only
//! merge information [`ontology::EntityTypeDef`] carries, and it is a pure
//! function of the primitive, not stored per-property. That means:
//!
//! - Every merge-strategy change reachable today is also a primitive retype
//!   (there is no way to change `String`'s merge from `lww` to anything else
//!   without changing the property's primitive), so it is already caught by
//!   [`Compatibility::Breaking`]'s retype rule — not missed, just not a
//!   separately named case.
//! - There is, correspondingly, no structural change expressible in today's
//!   [`ontology::EntityTypeDef`] that is additive to *data* but still
//!   demands a migration step before existing rows are safe to read under
//!   it — which is what [`Compatibility::CompatiblePlus`] means. That case
//!   needs the per-property merge/policy override `ontology` itself defers;
//!   inventing one here to give this module something to return would be
//!   exactly the "eight-field policy struct with unspecified enum variants"
//!   the `ontology` module doc already declined to do. [`classify`] stays
//!   two-valued in practice until that lands.
//!
//! # Enforcement, not just detection
//!
//! [`SchemaRegistry`] is where a capability tells the runtime what it
//! currently expects (and, optionally, what it used to expect) a named
//! schema to look like. [`check_replay_compatible`] — and
//! [`crate::runtime::Runtime::replay_schema_checked`], the integration point
//! — walks a replayed operation list and refuses outright the moment an
//! operation's stored [`crate::runtime::Operation::schema_id`] resolves to a
//! [`Compatibility::Breaking`] or unrecognized version, rather than silently
//! projecting data written under a schema the running code no longer agrees
//! with. An operation with an empty `schema_id` (every capability that has
//! not adopted [`ontology::EntityTypeDef`] yet, including every existing
//! [`crate::notes`] operation) is not checked at all — additive, per the
//! same "does not touch what came before" discipline [`ontology`] states for
//! itself.

use std::collections::BTreeMap;

use crate::digest::Sha256;
use crate::ontology::EntityTypeDef;
use crate::runtime::Operation;

fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    h.finish()
}

fn push_str(out: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

/// The canonical bytes [`fingerprint`] hashes. Length-prefixed, no serde —
/// the same wire discipline [`crate::ontology`] and [`crate::runtime`] both
/// already follow, for the same reason: a serde derive's field order and a
/// struct's declaration order are both accidents of the Rust source, not a
/// stability guarantee across a dependency bump.
///
/// Deliberately **excludes** [`EntityTypeDef::labels`] — the `ontology`
/// module doc's own words: *"`labels` carry the domain meaning ... `name`/
/// `extends`/`properties` carry none."* A label rename is a display change,
/// not a structural one; folding it into the fingerprint would make
/// relabeling indistinguishable from a real schema change, which is the
/// opposite of what a fingerprint is for. [`EntityTypeDef::properties`] is a
/// `BTreeMap`, so iteration here is already in a deterministic, sorted
/// order — no separate sort step needed.
fn canonical_bytes(def: &EntityTypeDef) -> Vec<u8> {
    let mut out = Vec::new();
    push_str(&mut out, &def.name);
    push_str(&mut out, def.extends.as_str());
    out.extend_from_slice(&(def.properties.len() as u32).to_be_bytes());
    for (name, primitive) in &def.properties {
        push_str(&mut out, name);
        push_str(&mut out, primitive.as_str());
    }
    out
}

/// `Schema → canonical serialization → SHA-256 → schemaId`, the issue's own
/// diagram: hex SHA-256 over [`canonical_bytes`]. Two [`EntityTypeDef`]s that
/// differ only in [`EntityTypeDef::labels`] fingerprint identically; any
/// difference in name, `extends`, or a property's name/[`crate::ontology::Primitive`]
/// fingerprints differently.
pub fn fingerprint(def: &EntityTypeDef) -> String {
    sha256_hex(&canonical_bytes(def))
}

/// [`EntityTypeDef::schema_id`] joined to [`fingerprint`] with `@` — the
/// value actually stored in [`Operation::schema_id`], so a stored operation
/// names both *which* type it was written against and *which exact
/// structural version* of it. `@` cannot appear inside
/// [`EntityTypeDef::schema_id`]'s output (`"capability." `+ a name), so the
/// join is unambiguous to split back with [`split_schema_fingerprint_id`].
pub fn schema_fingerprint_id(def: &EntityTypeDef) -> String {
    format!("{}@{}", def.schema_id(), fingerprint(def))
}

/// The inverse of [`schema_fingerprint_id`]'s join: `(schema_id, fingerprint)`,
/// splitting on the *last* `@` so a hypothetical `@` inside a capability's own
/// chosen type name does not break the split. `None` for a string with no
/// `@` at all — not this module's format, most likely a bare
/// [`EntityTypeDef::schema_id`] from before `#1226` or a capability that has
/// not adopted either.
pub fn split_schema_fingerprint_id(id: &str) -> Option<(&str, &str)> {
    id.rsplit_once('@')
}

// ---------------------------------------------------------------------------
// Compatibility classes
// ---------------------------------------------------------------------------

/// The issue's own table, verbatim:
///
/// | Compatibility class | Meaning |
/// |---|---|
/// | `compatible` | Additive. No migration. |
/// | `compatible+` | Migration required. |
/// | `breaking` | New lineage. Not a version bump. |
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Compatibility {
    /// Additive. No migration. See the module doc for exactly what
    /// "additive" means given [`EntityTypeDef`] has no required/optional
    /// distinction.
    Compatible,
    /// Migration required. Not returned by [`classify`] today — see the
    /// module doc's "Honestly incomplete" section for why.
    CompatiblePlus,
    /// New lineage, not a version bump. A stored operation under the old
    /// version cannot be safely read as the new one.
    Breaking,
}

impl Compatibility {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Compatible => "compatible",
            Self::CompatiblePlus => "compatible+",
            Self::Breaking => "breaking",
        }
    }
}

/// Classifies the change from `old` to `new`. Both must be **the same
/// schema's lineage** to compare meaningfully; a `name` or `extends`
/// difference is treated as [`Compatibility::Breaking`] rather than
/// "incomparable", per the issue: a name/extends change is not this schema
/// evolving, it is a different schema that happens to share a fingerprint
/// input shape.
///
/// See the module doc for the full compatible/breaking rule and why
/// [`Compatibility::CompatiblePlus`] is never returned yet.
pub fn classify(old: &EntityTypeDef, new: &EntityTypeDef) -> Compatibility {
    if old.name != new.name || old.extends != new.extends {
        return Compatibility::Breaking;
    }
    for (name, old_primitive) in &old.properties {
        match new.properties.get(name) {
            None => return Compatibility::Breaking, // removed
            Some(new_primitive) if new_primitive != old_primitive => {
                return Compatibility::Breaking; // retyped
            }
            Some(_) => {}
        }
    }
    // Every old property survives, unchanged in primitive. Anything left in
    // `new.properties` is either identical or a pure addition -- both
    // additive.
    Compatibility::Compatible
}

// ---------------------------------------------------------------------------
// SchemaRegistry — what a capability tells the runtime it currently expects
// ---------------------------------------------------------------------------

/// A capability's own record of what a named schema currently looks like,
/// and (optionally) what it used to look like — the runtime cannot classify
/// a fingerprint found in a stored operation against a definition it has
/// never seen, so a capability that wants old data readable across a schema
/// change must register the prior [`EntityTypeDef`] too, not just its
/// fingerprint. `BTreeMap`, matching every other deterministic-iteration
/// collection in this crate (`C2`).
#[derive(Default)]
pub struct SchemaRegistry {
    /// Every definition this registry has ever been told about, keyed by its
    /// own [`fingerprint`]. Includes both current and prior versions.
    known: BTreeMap<String, EntityTypeDef>,
    /// `schema_id` (name-level, e.g. `"capability.Doctor"`) → the fingerprint
    /// that is *currently* correct for it.
    current: BTreeMap<String, String>,
}

impl SchemaRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers `def` as the current version of its `schema_id`. Returns
    /// the [`schema_fingerprint_id`] a capability should now stamp onto
    /// every new [`Operation`] it emits for this type.
    pub fn register_current(&mut self, def: EntityTypeDef) -> String {
        let fp = fingerprint(&def);
        let sid = def.schema_id();
        self.known.insert(fp.clone(), def);
        self.current.insert(sid.clone(), fp.clone());
        format!("{sid}@{fp}")
    }

    /// Registers `def` as a version this schema used to be, without making
    /// it current — the seam [`Self::register_current`] does not cover: a
    /// migration or a compatibility check for old data needs the *old*
    /// structure on hand, not just its hash, and a hash cannot be inverted
    /// back into the definition that produced it.
    pub fn register_known(&mut self, def: EntityTypeDef) {
        self.known.insert(fingerprint(&def), def);
    }

    /// The [`schema_fingerprint_id`] currently correct for `schema_id`, if
    /// anything has been registered as current for it.
    pub fn current_schema_fingerprint_id(&self, schema_id: &str) -> Option<String> {
        self.current
            .get(schema_id)
            .map(|fp| format!("{schema_id}@{fp}"))
    }

    /// Decides what to do with an operation whose
    /// [`Operation::schema_id`] is `stamped` — the full `schema_id@fingerprint`
    /// form [`schema_fingerprint_id`] produces, exactly as
    /// [`check_replay_compatible`] finds it on a durable [`Operation`].
    pub fn decide(&self, stamped: &str) -> ReplayDecision {
        let Some((schema_id, fp)) = split_schema_fingerprint_id(stamped) else {
            return ReplayDecision::Unknown;
        };
        let Some(current_fp) = self.current.get(schema_id) else {
            return ReplayDecision::Unknown;
        };
        if current_fp == fp {
            return ReplayDecision::Current;
        }
        let (Some(old_def), Some(current_def)) = (self.known.get(fp), self.known.get(current_fp))
        else {
            // A fingerprint the registry has never seen the definition for
            // cannot be classified -- conservatively unknown, not assumed
            // safe. See `Self::register_known`'s doc.
            return ReplayDecision::Unknown;
        };
        match classify(old_def, current_def) {
            Compatibility::Compatible => ReplayDecision::Compatible,
            Compatibility::CompatiblePlus => ReplayDecision::RequiresMigration,
            Compatibility::Breaking => ReplayDecision::Breaking,
        }
    }
}

/// What [`SchemaRegistry::decide`] concluded about one stamped schema id.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ReplayDecision {
    /// Exactly the schema currently registered — nothing to reconcile.
    Current,
    /// An older, additive-compatible version. Safe to read as-is.
    Compatible,
    /// An older version whose change from `old` to `current` is
    /// [`Compatibility::CompatiblePlus`] — not returned by [`classify`]
    /// today, so not reachable through [`SchemaRegistry::decide`] either;
    /// kept so the match in [`check_replay_compatible`] is exhaustive and
    /// does not need a wildcard arm that would silently swallow a future
    /// case.
    RequiresMigration,
    /// A structurally incompatible version, or a `schema_id` this registry
    /// has never seen registered as current at all.
    Breaking,
    /// The stamped id did not parse as `schema_id@fingerprint`, or named a
    /// `schema_id` this registry has nothing current for, or named a
    /// fingerprint the registry was never given the definition for.
    /// Treated identically to [`Self::Breaking`] by
    /// [`check_replay_compatible`] — an operation this runtime cannot
    /// classify at all is not safer than one it can classify as
    /// incompatible.
    Unknown,
}

/// Why [`check_replay_compatible`] refused a replay.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaViolation {
    /// The offending operation's [`crate::runtime::Operation::seq`].
    pub seq: u64,
    /// The offending operation's raw [`crate::runtime::Operation::schema_id`].
    pub schema_id: String,
    pub decision: ReplayDecision,
}

impl std::fmt::Display for SchemaViolation {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.decision {
            ReplayDecision::Breaking => write!(
                f,
                "operation {} was written under schema '{}', which is a breaking-incompatible version of what this runtime currently expects; refusing replay",
                self.seq, self.schema_id
            ),
            ReplayDecision::RequiresMigration => write!(
                f,
                "operation {} was written under schema '{}', which requires a migration before it can be read under the current schema; refusing replay",
                self.seq, self.schema_id
            ),
            ReplayDecision::Unknown => write!(
                f,
                "operation {} was written under schema '{}', which this runtime does not recognize; refusing replay",
                self.seq, self.schema_id
            ),
            ReplayDecision::Current | ReplayDecision::Compatible => write!(
                f,
                "operation {} under schema '{}' is not actually a violation (internal error constructing SchemaViolation)",
                self.seq, self.schema_id
            ),
        }
    }
}

impl std::error::Error for SchemaViolation {}

/// Walks `ops` in order and refuses the moment one's
/// [`Operation::schema_id`] resolves — through `registry` — to anything
/// other than [`ReplayDecision::Current`] or [`ReplayDecision::Compatible`].
/// An empty `schema_id` is never checked (see the module doc: every
/// capability that has not adopted [`EntityTypeDef`] yet keeps working
/// unchanged).
///
/// This is the enforcement half of the issue's scope line *"Compatibility
/// classification enforced at validation, not left to the author's version
/// number"* — a capability cannot simply declare its new schema compatible
/// by fiat; [`classify`] decides, and this function is what actually acts on
/// that decision rather than only logging it.
pub fn check_replay_compatible(
    registry: &SchemaRegistry,
    ops: &[Operation],
) -> Result<(), SchemaViolation> {
    for op in ops {
        if op.schema_id.is_empty() {
            continue;
        }
        let decision = registry.decide(&op.schema_id);
        match decision {
            ReplayDecision::Current | ReplayDecision::Compatible => {}
            ReplayDecision::RequiresMigration
            | ReplayDecision::Breaking
            | ReplayDecision::Unknown => {
                return Err(SchemaViolation {
                    seq: op.seq,
                    schema_id: op.schema_id.clone(),
                    decision,
                });
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ontology::{CoreEntityType, Primitive};

    fn doctor_v1() -> EntityTypeDef {
        EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_label("Doctor")
            .with_property("speciality", Primitive::String)
    }

    // -- Fingerprint: structural identity, not incidental identity ---------

    #[test]
    fn two_structurally_identical_defs_fingerprint_identically() {
        let a = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("yearsPracticing", Primitive::Number);
        let b = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("yearsPracticing", Primitive::Number) // different insertion order
            .with_property("speciality", Primitive::String);
        assert_eq!(fingerprint(&a), fingerprint(&b));
    }

    #[test]
    fn a_label_only_difference_does_not_change_the_fingerprint() {
        let a = doctor_v1();
        let b = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_label("Doctor")
            .with_label("Clinician") // extra label, no structural change
            .with_property("speciality", Primitive::String);
        assert_eq!(fingerprint(&a), fingerprint(&b));
    }

    #[test]
    fn two_structurally_different_defs_fingerprint_differently() {
        let a = doctor_v1();

        let different_property_type = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::Text);
        assert_ne!(fingerprint(&a), fingerprint(&different_property_type));

        let different_property_name = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("field", Primitive::String);
        assert_ne!(fingerprint(&a), fingerprint(&different_property_name));

        let different_name = EntityTypeDef::new("Clinician", CoreEntityType::Person)
            .with_property("speciality", Primitive::String);
        assert_ne!(fingerprint(&a), fingerprint(&different_name));

        let different_extends = EntityTypeDef::new("Doctor", CoreEntityType::Organization)
            .with_property("speciality", Primitive::String);
        assert_ne!(fingerprint(&a), fingerprint(&different_extends));

        let extra_property = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("clinic", Primitive::Reference);
        assert_ne!(fingerprint(&a), fingerprint(&extra_property));
    }

    #[test]
    fn schema_fingerprint_id_splits_back_into_its_two_halves() {
        let doctor = doctor_v1();
        let stamped = schema_fingerprint_id(&doctor);
        let (schema_id, fp) = split_schema_fingerprint_id(&stamped).unwrap();
        assert_eq!(schema_id, doctor.schema_id());
        assert_eq!(fp, fingerprint(&doctor));
    }

    #[test]
    fn a_string_with_no_at_sign_does_not_split() {
        assert_eq!(split_schema_fingerprint_id("capability.Doctor"), None);
    }

    // -- Compatibility classification ---------------------------------------

    #[test]
    fn adding_a_new_property_is_compatible() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("yearsPracticing", Primitive::Number); // additive
        assert_eq!(classify(&old, &new), Compatibility::Compatible);
    }

    #[test]
    fn an_identical_def_is_compatible_with_itself() {
        let old = doctor_v1();
        let new = doctor_v1();
        assert_eq!(classify(&old, &new), Compatibility::Compatible);
    }

    #[test]
    fn a_label_only_change_is_compatible() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_label("Doctor")
            .with_label("Clinician")
            .with_property("speciality", Primitive::String);
        assert_eq!(classify(&old, &new), Compatibility::Compatible);
    }

    #[test]
    fn removing_a_required_property_is_breaking() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Doctor", CoreEntityType::Person); // speciality gone
        assert_eq!(classify(&old, &new), Compatibility::Breaking);
    }

    #[test]
    fn retyping_a_property_is_breaking() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::Text); // String -> Text
        assert_eq!(classify(&old, &new), Compatibility::Breaking);
    }

    #[test]
    fn changing_extends_is_breaking_new_lineage() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Doctor", CoreEntityType::Organization)
            .with_property("speciality", Primitive::String);
        assert_eq!(classify(&old, &new), Compatibility::Breaking);
    }

    #[test]
    fn changing_the_name_is_breaking_new_lineage() {
        let old = doctor_v1();
        let new = EntityTypeDef::new("Clinician", CoreEntityType::Person)
            .with_property("speciality", Primitive::String);
        assert_eq!(classify(&old, &new), Compatibility::Breaking);
    }

    // -- SchemaRegistry / replay enforcement --------------------------------

    #[test]
    fn an_operation_stamped_with_the_current_schema_is_current() {
        let mut registry = SchemaRegistry::new();
        let stamped = registry.register_current(doctor_v1());
        assert_eq!(registry.decide(&stamped), ReplayDecision::Current);
    }

    #[test]
    fn an_operation_stamped_with_a_known_compatible_prior_version_is_compatible() {
        let mut registry = SchemaRegistry::new();
        let v1 = doctor_v1();
        let v1_stamped = schema_fingerprint_id(&v1);
        registry.register_known(v1);

        let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("yearsPracticing", Primitive::Number); // additive
        registry.register_current(v2);

        assert_eq!(registry.decide(&v1_stamped), ReplayDecision::Compatible);
    }

    #[test]
    fn an_operation_stamped_with_a_known_breaking_prior_version_is_breaking() {
        let mut registry = SchemaRegistry::new();
        let v1 = doctor_v1();
        let v1_stamped = schema_fingerprint_id(&v1);
        registry.register_known(v1);

        let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::Text); // retyped: breaking
        registry.register_current(v2);

        assert_eq!(registry.decide(&v1_stamped), ReplayDecision::Breaking);
    }

    #[test]
    fn an_unregistered_schema_id_is_unknown() {
        let registry = SchemaRegistry::new();
        assert_eq!(
            registry.decide("capability.Doctor@deadbeef"),
            ReplayDecision::Unknown
        );
    }

    #[test]
    fn a_fingerprint_the_registry_never_saw_the_definition_for_is_unknown_not_assumed_safe() {
        let mut registry = SchemaRegistry::new();
        registry.register_current(doctor_v1());
        // A different, never-registered fingerprint under the same schema_id.
        assert_eq!(
            registry.decide("capability.Doctor@0000000000000000000000000000000000000000000000000000000000000000"),
            ReplayDecision::Unknown
        );
    }

    fn sample_op(seq: u64, schema_id: &str) -> Operation {
        // `Operation` has no public constructor (its fields are assembled
        // only by `OperationLog::append`); build one by hand here the same
        // way `runtime`'s own doc-test-adjacent unit tests would need to if
        // they wanted an `Operation` without a real log.
        Operation {
            seq,
            operation_id: format!("op-{seq}"),
            parent_operation_id: None,
            entity_id: String::new(),
            context_ids: Vec::new(),
            schema_id: schema_id.to_string(),
            capability: "doctors".to_string(),
            kind: "SetProperty".to_string(),
            device_id: "device-1".to_string(),
            recorded_at_ms: seq,
            version_vector: BTreeMap::new(),
            payload_hash: String::new(),
            signature: Vec::new(),
            payload: Vec::new(),
            content_id: None,
        }
    }

    #[test]
    fn replay_accepts_operations_with_no_schema_id_unconditionally() {
        let registry = SchemaRegistry::new();
        let ops = vec![sample_op(0, "")];
        assert!(check_replay_compatible(&registry, &ops).is_ok());
    }

    #[test]
    fn replay_accepts_operations_stamped_with_the_current_schema() {
        let mut registry = SchemaRegistry::new();
        let stamped = registry.register_current(doctor_v1());
        let ops = vec![sample_op(0, &stamped)];
        assert!(check_replay_compatible(&registry, &ops).is_ok());
    }

    #[test]
    fn replay_accepts_operations_stamped_with_a_compatible_prior_version() {
        let mut registry = SchemaRegistry::new();
        let v1 = doctor_v1();
        let v1_stamped = schema_fingerprint_id(&v1);
        registry.register_known(v1);
        let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("yearsPracticing", Primitive::Number);
        registry.register_current(v2);

        let ops = vec![sample_op(0, &v1_stamped)];
        assert!(check_replay_compatible(&registry, &ops).is_ok());
    }

    #[test]
    fn replay_refuses_at_the_first_breaking_incompatible_operation() {
        let mut registry = SchemaRegistry::new();
        let v1 = doctor_v1();
        let v1_stamped = schema_fingerprint_id(&v1);
        registry.register_known(v1);
        let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::Text); // retyped: breaking
        registry.register_current(v2);

        let ops = vec![
            sample_op(0, ""),          // untyped, always fine
            sample_op(1, &v1_stamped), // breaking
            sample_op(2, &v1_stamped), // never reached
        ];
        let err = check_replay_compatible(&registry, &ops).unwrap_err();
        assert_eq!(err.seq, 1);
        assert_eq!(err.decision, ReplayDecision::Breaking);
    }

    #[test]
    fn replay_refuses_an_unrecognized_schema_id_rather_than_assuming_it_safe() {
        let registry = SchemaRegistry::new();
        let ops = vec![sample_op(0, "capability.Doctor@deadbeef")];
        let err = check_replay_compatible(&registry, &ops).unwrap_err();
        assert_eq!(err.decision, ReplayDecision::Unknown);
    }

    #[test]
    fn schema_violation_display_names_the_offending_operation() {
        let registry = SchemaRegistry::new();
        let ops = vec![sample_op(7, "capability.Doctor@deadbeef")];
        let err = check_replay_compatible(&registry, &ops).unwrap_err();
        let rendered = err.to_string();
        assert!(rendered.contains('7'));
        assert!(rendered.contains("capability.Doctor@deadbeef"));
    }
}
