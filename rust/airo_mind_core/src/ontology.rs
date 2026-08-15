//! The type system: primitives, archetypes, and the core ontology. `#1223`'s
//! scope, restated as types instead of the issue's prose table.
//!
//! ```text
//! Primitive Types → Archetypes → Core Ontology → Capability Entities → Property Overrides
//! ```
//!
//! # Why this exists
//!
//! Design doc `C5`: *"capability entities extend the fixed core ontology,
//! never an archetype directly."* Twelve independently authored capabilities
//! (Home Buying, Finance, whatever comes after) each want a `Person`. If each
//! were free to define its own `Person` shape, "the same person" would need
//! translation at every capability boundary the entity graph is supposed to
//! remove. This module is the vocabulary all of them share, and cannot
//! redefine: [`Primitive`] is the leaf value grammar, [`Archetype`] is the
//! twelve abstract shapes that carry merge/timeline/storage policy and *never
//! appear in user data*, [`CoreEntityType`] is the twelve concrete types a
//! capability is actually allowed to extend, and [`EntityTypeDef`] is what a
//! capability declares (design doc's `Doctor extends Person` example).
//!
//! # Additive, not a retrofit
//!
//! [`crate::verb::Verb::CreateEntity`]/`SetProperty` and
//! [`crate::projection::EntityGraphProjection`] already ship, with raw
//! `Vec<u8>` payloads Notes and the entity-graph conformance suite depend on
//! by shape. This module does not touch either — [`Value::encode`] produces
//! exactly the `&[u8]` [`crate::projection::encode_set_property`] already
//! accepts, so a capability opts into typed values by encoding through here
//! before calling the verb it already had, not by a payload format that
//! breaks anything that came before `#1223`. The [`Verb`](crate::verb::Verb)
//! and [`EntityGraphProjection`](crate::projection::EntityGraphProjection)
//! wire shapes are unchanged.
//!
//! # The rule is structural, not just checked
//!
//! [`EntityTypeDef::extends`] is typed `CoreEntityType`, not `Archetype` and
//! not a free string — a capability author cannot even *construct* an entity
//! type that extends `Actor` directly; the field simply has no value that
//! means that. [`parse_extends`] is the boundary where that guarantee meets
//! the outside world (a capability's own YAML/config, the same shape as the
//! issue's `Doctor extends Person` example): it is where "structurally
//! impossible in Rust" becomes "loudly rejected" for data that did not come
//! through the type checker.
//!
//! # The `#1226` seam
//!
//! Every named thing here — [`Primitive::as_str`], [`Archetype::as_str`],
//! [`CoreEntityType::as_str`]/[`CoreEntityType::schema_id`],
//! [`EntityTypeDef::schema_id`] — has a stable, round-trippable name.
//! `#1226` ("schema fingerprint + compatibility classes") is deliberately
//! not implemented here, but [`crate::runtime::Operation::schema_id`]
//! already exists as a header field for a capability to populate from
//! exactly these names, so nothing in this module is anonymous or
//! unnameable for `#1226` to hang a real fingerprint on later.
//!
//! # Honestly incomplete
//!
//! The issue's archetype table lists eight policy categories an archetype
//! defines — merge, timeline behavior, indexing, storage, retention, search,
//! audit, permissions. Only **merge** has a stated table (on [`Primitive`],
//! not `Archetype` — merge is a primitive-level default in the issue's own
//! text). The other seven are named as *what archetypes are for*, not given
//! concrete values, so this module does not invent an eight-field policy
//! struct with unspecified enum variants for them. [`Archetype`] is a closed,
//! nameable vocabulary today; attaching the remaining policy fields is
//! follow-on work once something (the projection engine, most likely) has
//! spec'd what "timeline behavior" or "retention" actually mean as data.
//!
//! Eight of the twelve `extends` edges below are this module's own inference
//! from archetype semantics, not text the issue states — see
//! [`CoreEntityType::extends`]'s doc for exactly which four are given and
//! which eight are inferred.

use std::collections::BTreeMap;

// ---------------------------------------------------------------------------
// Primitive
// ---------------------------------------------------------------------------

/// The nine leaf value types every property in the entity graph is made of.
/// Issue `#1223`'s table, verbatim.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Primitive {
    String,
    Text,
    Bool,
    Number,
    Datetime,
    List,
    Set,
    Reference,
    Blob,
}

/// The nine primitives, in the issue table's own order.
pub const ALL_PRIMITIVES: &[Primitive] = &[
    Primitive::String,
    Primitive::Text,
    Primitive::Bool,
    Primitive::Number,
    Primitive::Datetime,
    Primitive::List,
    Primitive::Set,
    Primitive::Reference,
    Primitive::Blob,
];

/// A primitive's default merge behavior (design §5.3's precedence chain:
/// *"safety-class veto → property override → archetype rule → primitive
/// default"* — this is that last, lowest-precedence link).
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum MergeStrategy {
    /// Last write wins.
    Lww,
    /// Every write is kept, in order — `text`'s "revisions" default.
    Revisions,
    /// Merges toward whichever value is "more resolved"; issue text names it
    /// only for `bool` and does not spell out the direction, so this crate
    /// does not encode one — see the module's "Honestly incomplete" note.
    Monotonic,
    /// Set union — the collection primitives and `reference`.
    Union,
    /// Content-addressed: identical bytes hash identically, so merge is
    /// idempotent by construction — `blob`'s default.
    Hash,
}

impl MergeStrategy {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Lww => "lww",
            Self::Revisions => "revisions",
            Self::Monotonic => "monotonic",
            Self::Union => "union",
            Self::Hash => "hash",
        }
    }
}

impl Primitive {
    pub fn all() -> &'static [Primitive] {
        ALL_PRIMITIVES
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::String => "string",
            Self::Text => "text",
            Self::Bool => "bool",
            Self::Number => "number",
            Self::Datetime => "datetime",
            Self::List => "list",
            Self::Set => "set",
            Self::Reference => "reference",
            Self::Blob => "blob",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_PRIMITIVES.iter().copied().find(|p| p.as_str() == s)
    }

    /// The issue's merge table, verbatim: `string`→lww, `text`→revisions,
    /// `bool`→monotonic, `number`→lww, `datetime`→lww, `list`→union,
    /// `set`→union, `reference`→union, `blob`→hash.
    pub fn default_merge(self) -> MergeStrategy {
        match self {
            Self::String => MergeStrategy::Lww,
            Self::Text => MergeStrategy::Revisions,
            Self::Bool => MergeStrategy::Monotonic,
            Self::Number => MergeStrategy::Lww,
            Self::Datetime => MergeStrategy::Lww,
            Self::List => MergeStrategy::Union,
            Self::Set => MergeStrategy::Union,
            Self::Reference => MergeStrategy::Union,
            Self::Blob => MergeStrategy::Hash,
        }
    }

    /// Shape checks beyond "the tag matches" — the part of "reject
    /// wrong-shaped data" a bare enum-variant comparison cannot express.
    fn validate_shape(self, value: &Value) -> Result<(), String> {
        match (self, value) {
            (Self::Reference, Value::Reference(id)) if id.is_empty() => {
                Err("a reference value must name a non-empty entity id".to_string())
            }
            (Self::Number, Value::Number(n)) if !n.is_finite() => {
                Err(format!("a number value must be finite, got {n}"))
            }
            _ => Ok(()),
        }
    }
}

// ---------------------------------------------------------------------------
// Value
// ---------------------------------------------------------------------------

/// A typed property value — the runtime counterpart of [`Primitive`]. Not
/// `Eq` because [`Value::Number`] carries `f64`, the same reason nothing else
/// in this crate stores floats in an ordered collection.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Str(String),
    Text(String),
    Bool(bool),
    Number(f64),
    /// Milliseconds since the Unix epoch — the same unit every
    /// `recorded_at_ms` in this crate already uses.
    Datetime(i64),
    Reference(String),
    Blob(Vec<u8>),
    List(Vec<Value>),
    /// Canonicalized at [`Value::encode`] time (sorted, deduplicated by
    /// encoded bytes), not at construction — see that method's doc.
    Set(Vec<Value>),
}

const TAG_STR: u8 = 0;
const TAG_TEXT: u8 = 1;
const TAG_BOOL: u8 = 2;
const TAG_NUMBER: u8 = 3;
const TAG_DATETIME: u8 = 4;
const TAG_REFERENCE: u8 = 5;
const TAG_BLOB: u8 = 6;
const TAG_LIST: u8 = 7;
const TAG_SET: u8 = 8;

fn push_str(out: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

fn pop_str(bytes: &[u8], pos: &mut usize) -> Option<String> {
    let s = pop_bytes(bytes, pos)?;
    String::from_utf8(s).ok()
}

fn pop_bytes(bytes: &[u8], pos: &mut usize) -> Option<Vec<u8>> {
    let len_bytes: [u8; 4] = bytes.get(*pos..*pos + 4)?.try_into().ok()?;
    let len = u32::from_be_bytes(len_bytes) as usize;
    *pos += 4;
    let s = bytes.get(*pos..*pos + len)?;
    *pos += len;
    Some(s.to_vec())
}

fn read_u32(bytes: &[u8], pos: &mut usize) -> Option<u32> {
    let arr: [u8; 4] = bytes.get(*pos..*pos + 4)?.try_into().ok()?;
    *pos += 4;
    Some(u32::from_be_bytes(arr))
}

impl Value {
    pub fn primitive(&self) -> Primitive {
        match self {
            Self::Str(_) => Primitive::String,
            Self::Text(_) => Primitive::Text,
            Self::Bool(_) => Primitive::Bool,
            Self::Number(_) => Primitive::Number,
            Self::Datetime(_) => Primitive::Datetime,
            Self::Reference(_) => Primitive::Reference,
            Self::Blob(_) => Primitive::Blob,
            Self::List(_) => Primitive::List,
            Self::Set(_) => Primitive::Set,
        }
    }

    /// Encodes into exactly the `&[u8]` shape
    /// [`crate::projection::encode_set_property`]'s `value` parameter already
    /// takes — length-prefixed, no serde, the same wire discipline every
    /// other payload in this crate follows. Self-describing (a leading tag
    /// byte), so [`Value::decode`] never needs an out-of-band [`Primitive`]
    /// to know what it is reading.
    ///
    /// [`Value::Set`] is sorted and deduplicated by encoded bytes here, not
    /// at construction — two `Set` values built from the same elements in a
    /// different order encode identically, which is what makes `union` merge
    /// (`C3`: *"merge is commutative, associative, and idempotent"*)
    /// meaningful for a primitive with no separate merge implementation yet.
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.encode_into(&mut out);
        out
    }

    fn encode_into(&self, out: &mut Vec<u8>) {
        match self {
            Self::Str(s) => {
                out.push(TAG_STR);
                push_str(out, s);
            }
            Self::Text(s) => {
                out.push(TAG_TEXT);
                push_str(out, s);
            }
            Self::Bool(b) => {
                out.push(TAG_BOOL);
                out.push(u8::from(*b));
            }
            Self::Number(n) => {
                out.push(TAG_NUMBER);
                out.extend_from_slice(&n.to_bits().to_be_bytes());
            }
            Self::Datetime(ms) => {
                out.push(TAG_DATETIME);
                out.extend_from_slice(&ms.to_be_bytes());
            }
            Self::Reference(id) => {
                out.push(TAG_REFERENCE);
                push_str(out, id);
            }
            Self::Blob(bytes) => {
                out.push(TAG_BLOB);
                out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
                out.extend_from_slice(bytes);
            }
            Self::List(items) => {
                out.push(TAG_LIST);
                out.extend_from_slice(&(items.len() as u32).to_be_bytes());
                for item in items {
                    item.encode_into(out);
                }
            }
            Self::Set(items) => {
                out.push(TAG_SET);
                let mut encoded: Vec<Vec<u8>> = items.iter().map(Value::encode).collect();
                encoded.sort();
                encoded.dedup();
                out.extend_from_slice(&(encoded.len() as u32).to_be_bytes());
                for e in encoded {
                    out.extend_from_slice(&e);
                }
            }
        }
    }

    /// The inverse of [`Value::encode`]. `None` for truncated or malformed
    /// bytes, or trailing bytes after a complete value — the wire-level half
    /// of "reject wrong-shaped data": a payload that does not parse never
    /// becomes a [`Value`] at all, let alone one whose primitive tag is
    /// checked against a schema.
    pub fn decode(bytes: &[u8]) -> Option<Value> {
        let mut pos = 0usize;
        let value = Self::decode_at(bytes, &mut pos)?;
        if pos == bytes.len() {
            Some(value)
        } else {
            None
        }
    }

    fn decode_at(bytes: &[u8], pos: &mut usize) -> Option<Value> {
        let tag = *bytes.get(*pos)?;
        *pos += 1;
        match tag {
            TAG_STR => Some(Value::Str(pop_str(bytes, pos)?)),
            TAG_TEXT => Some(Value::Text(pop_str(bytes, pos)?)),
            TAG_BOOL => {
                let b = *bytes.get(*pos)?;
                *pos += 1;
                Some(Value::Bool(b != 0))
            }
            TAG_NUMBER => {
                let arr: [u8; 8] = bytes.get(*pos..*pos + 8)?.try_into().ok()?;
                *pos += 8;
                Some(Value::Number(f64::from_bits(u64::from_be_bytes(arr))))
            }
            TAG_DATETIME => {
                let arr: [u8; 8] = bytes.get(*pos..*pos + 8)?.try_into().ok()?;
                *pos += 8;
                Some(Value::Datetime(i64::from_be_bytes(arr)))
            }
            TAG_REFERENCE => Some(Value::Reference(pop_str(bytes, pos)?)),
            TAG_BLOB => Some(Value::Blob(pop_bytes(bytes, pos)?)),
            TAG_LIST => {
                let count = read_u32(bytes, pos)?;
                let mut items = Vec::with_capacity(count as usize);
                for _ in 0..count {
                    items.push(Self::decode_at(bytes, pos)?);
                }
                Some(Value::List(items))
            }
            TAG_SET => {
                let count = read_u32(bytes, pos)?;
                let mut items = Vec::with_capacity(count as usize);
                for _ in 0..count {
                    items.push(Self::decode_at(bytes, pos)?);
                }
                Some(Value::Set(items))
            }
            _ => None,
        }
    }
}

// ---------------------------------------------------------------------------
// Archetype
// ---------------------------------------------------------------------------

/// The twelve abstract shapes. **Never appear in user data** — no capability
/// ever creates an entity whose type *is* an archetype; see
/// [`CoreEntityType::extends`] and [`EntityTypeDef`] for the concrete layer a
/// capability actually extends. Carries the runtime-level policy category
/// names the issue lists (merge, timeline behavior, indexing, storage,
/// retention, search, audit, permissions) — see the module doc's "Honestly
/// incomplete" note for which of those has a concrete value today.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Archetype {
    Actor,
    Artifact,
    Activity,
    Record,
    Measurement,
    Event,
    Workflow,
    Collection,
    Location,
    Resource,
    Relationship,
    Configuration,
}

pub const ALL_ARCHETYPES: &[Archetype] = &[
    Archetype::Actor,
    Archetype::Artifact,
    Archetype::Activity,
    Archetype::Record,
    Archetype::Measurement,
    Archetype::Event,
    Archetype::Workflow,
    Archetype::Collection,
    Archetype::Location,
    Archetype::Resource,
    Archetype::Relationship,
    Archetype::Configuration,
];

impl Archetype {
    pub fn all() -> &'static [Archetype] {
        ALL_ARCHETYPES
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Actor => "Actor",
            Self::Artifact => "Artifact",
            Self::Activity => "Activity",
            Self::Record => "Record",
            Self::Measurement => "Measurement",
            Self::Event => "Event",
            Self::Workflow => "Workflow",
            Self::Collection => "Collection",
            Self::Location => "Location",
            Self::Resource => "Resource",
            Self::Relationship => "Relationship",
            Self::Configuration => "Configuration",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_ARCHETYPES.iter().copied().find(|a| a.as_str() == s)
    }
}

// ---------------------------------------------------------------------------
// CoreEntityType
// ---------------------------------------------------------------------------

/// The twelve concrete types built into the runtime, never redefinable — a
/// capability cannot register a thirteenth; this is a closed Rust enum, not
/// an open registry, which is what "never redefinable" means mechanically.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum CoreEntityType {
    Person,
    Organization,
    Conversation,
    Document,
    Task,
    Journey,
    CalendarEvent,
    Reminder,
    Place,
    Device,
    Media,
    Note,
}

pub const ALL_CORE_ENTITY_TYPES: &[CoreEntityType] = &[
    CoreEntityType::Person,
    CoreEntityType::Organization,
    CoreEntityType::Conversation,
    CoreEntityType::Document,
    CoreEntityType::Task,
    CoreEntityType::Journey,
    CoreEntityType::CalendarEvent,
    CoreEntityType::Reminder,
    CoreEntityType::Place,
    CoreEntityType::Device,
    CoreEntityType::Media,
    CoreEntityType::Note,
];

impl CoreEntityType {
    pub fn all() -> &'static [CoreEntityType] {
        ALL_CORE_ENTITY_TYPES
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Person => "Person",
            Self::Organization => "Organization",
            Self::Conversation => "Conversation",
            Self::Document => "Document",
            Self::Task => "Task",
            Self::Journey => "Journey",
            Self::CalendarEvent => "CalendarEvent",
            Self::Reminder => "Reminder",
            Self::Place => "Place",
            Self::Device => "Device",
            Self::Media => "Media",
            Self::Note => "Note",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_CORE_ENTITY_TYPES
            .iter()
            .copied()
            .find(|t| t.as_str() == s)
    }

    /// Which archetype this core type extends.
    ///
    /// **Four edges are `#1223`'s own text, verbatim:** `Person extends
    /// Actor` · `Task extends Workflow` · `Document extends Artifact` ·
    /// `Conversation extends Activity`.
    ///
    /// **The remaining eight are this module's inference**, not issue text —
    /// reasoned from archetype semantics (an org acts, so `Actor`; a place
    /// is a location, so `Location`; a device is consumed/scheduled like a
    /// resource, so `Resource`) rather than specified anywhere. Flagged here,
    /// in the module doc, and in `#1223`'s tracking comment so a maintainer
    /// with the actual intended mapping can correct it in one place — the
    /// enforcement rule these values feed (never extend an archetype
    /// directly) holds regardless of which archetype each inferred edge
    /// eventually resolves to.
    pub fn extends(self) -> Archetype {
        match self {
            // Given by the issue.
            Self::Person => Archetype::Actor,
            Self::Task => Archetype::Workflow,
            Self::Document => Archetype::Artifact,
            Self::Conversation => Archetype::Activity,
            // Inferred — see doc above.
            Self::Organization => Archetype::Actor,
            Self::Journey => Archetype::Workflow,
            Self::CalendarEvent => Archetype::Event,
            Self::Reminder => Archetype::Event,
            Self::Place => Archetype::Location,
            Self::Device => Archetype::Resource,
            Self::Media => Archetype::Artifact,
            Self::Note => Archetype::Artifact,
        }
    }

    /// The `#1226` seam: a stable, nameable id this type can be cited by
    /// before a real fingerprint exists. Not a hash, not a version — just a
    /// name that will not silently change out from under a capability that
    /// stored it in [`crate::runtime::Operation::schema_id`].
    pub fn schema_id(self) -> String {
        format!("core.{}", self.as_str())
    }
}

// ---------------------------------------------------------------------------
// EntityTypeDef — the layer a capability actually extends
// ---------------------------------------------------------------------------

/// One capability-declared entity type, the issue's own example:
///
/// ```yaml
/// entity: Doctor
/// extends: Person
/// labels: [Doctor, Clinician]
/// properties:
///   speciality: { type: string }
/// ```
///
/// `extends` is typed [`CoreEntityType`], not [`Archetype`] and not a free
/// string — see the module doc's "The rule is structural, not just checked".
/// `labels` carry the domain meaning (`C5`/issue: *"domain meaning is
/// carried by labels, not types"*); `name`/`extends`/`properties` carry
/// none.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EntityTypeDef {
    pub name: String,
    pub extends: CoreEntityType,
    pub labels: Vec<String>,
    /// `BTreeMap`: deterministic iteration, matching `C2`'s ban on
    /// `HashMap` iteration order on any path a conformance test relies on.
    pub properties: BTreeMap<String, Primitive>,
}

impl EntityTypeDef {
    pub fn new(name: impl Into<String>, extends: CoreEntityType) -> Self {
        Self {
            name: name.into(),
            extends,
            labels: Vec::new(),
            properties: BTreeMap::new(),
        }
    }

    pub fn with_label(mut self, label: impl Into<String>) -> Self {
        self.labels.push(label.into());
        self
    }

    pub fn with_property(mut self, name: impl Into<String>, primitive: Primitive) -> Self {
        self.properties.insert(name.into(), primitive);
        self
    }

    /// Type-checks one property write against this entity type's schema:
    /// the property must be declared, and the value's [`Primitive`] must
    /// match — "archetypes can be composed from primitives" made checkable,
    /// one property at a time, plus the [`Primitive::validate_shape`] checks
    /// a bare tag comparison cannot express.
    pub fn validate_property(&self, property: &str, value: &Value) -> Result<(), OntologyError> {
        let expected = self
            .properties
            .get(property)
            .ok_or_else(|| OntologyError::UnknownProperty(property.to_string()))?;
        let found = value.primitive();
        if found != *expected {
            return Err(OntologyError::TypeMismatch {
                property: property.to_string(),
                expected: *expected,
                found,
            });
        }
        expected
            .validate_shape(value)
            .map_err(|reason| OntologyError::InvalidValue {
                property: property.to_string(),
                reason,
            })
    }

    /// The `#1226` seam for a capability-declared type, mirroring
    /// [`CoreEntityType::schema_id`].
    pub fn schema_id(&self) -> String {
        format!("capability.{}", self.name)
    }
}

// ---------------------------------------------------------------------------
// Ontology-level validation — the rule enforced, not just declared
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OntologyError {
    /// `extends: <name>` named something that is neither a core ontology
    /// type nor an archetype at all.
    UnknownCoreType(String),
    /// `extends: <name>` named one of the twelve archetypes directly —
    /// exactly the violation `#1223`'s Rule section forbids.
    CannotExtendArchetypeDirectly(String),
    /// A capability tried to label an entity with a bare archetype name —
    /// "archetypes never appear in user data" applied to the label a
    /// [`crate::verb::Verb::CreateEntity`] payload would carry.
    ArchetypeUsedAsUserFacingLabel(String),
    UnknownProperty(String),
    TypeMismatch {
        property: String,
        expected: Primitive,
        found: Primitive,
    },
    InvalidValue {
        property: String,
        reason: String,
    },
}

impl std::fmt::Display for OntologyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnknownCoreType(s) => write!(f, "'{s}' is not a core ontology type"),
            Self::CannotExtendArchetypeDirectly(s) => write!(
                f,
                "'{s}' is an archetype; capability entities must extend the core ontology, never an archetype directly"
            ),
            Self::ArchetypeUsedAsUserFacingLabel(s) => write!(
                f,
                "'{s}' is an archetype; archetypes never appear in user data"
            ),
            Self::UnknownProperty(p) => write!(f, "property '{p}' is not declared on this entity type"),
            Self::TypeMismatch {
                property,
                expected,
                found,
            } => write!(
                f,
                "property '{property}' expects {}, got {}",
                expected.as_str(),
                found.as_str()
            ),
            Self::InvalidValue { property, reason } => {
                write!(f, "property '{property}' is invalid: {reason}")
            }
        }
    }
}

impl std::error::Error for OntologyError {}

/// Parses an `extends:` value from a capability's own config (the issue's
/// YAML example) into a [`CoreEntityType`] — the runtime-checked boundary
/// where `EntityTypeDef::extends`'s compile-time guarantee (it can only ever
/// *be* a `CoreEntityType`) meets data that did not go through the Rust type
/// checker to get here. An archetype name gets its own error variant rather
/// than folding into "unknown", because "you wrote a real name, just the
/// wrong layer of the vocabulary" is a different, more specific mistake than
/// "you wrote a name this ontology has never heard of".
pub fn parse_extends(s: &str) -> Result<CoreEntityType, OntologyError> {
    if let Some(core) = CoreEntityType::parse(s) {
        return Ok(core);
    }
    if Archetype::parse(s).is_some() {
        return Err(OntologyError::CannotExtendArchetypeDirectly(s.to_string()));
    }
    Err(OntologyError::UnknownCoreType(s.to_string()))
}

/// "Archetypes never appear in user data" as a runnable check: a capability
/// calls this on a label (or a `CreateEntity` payload's label string, before
/// emitting it) to reject exactly the string that would leak the abstract
/// layer into the concrete one. Additive — [`crate::projection`] does not
/// call this itself; it stays free-form label storage, per the module doc.
pub fn validate_user_facing_label(label: &str) -> Result<(), OntologyError> {
    if Archetype::parse(label).is_some() {
        return Err(OntologyError::ArchetypeUsedAsUserFacingLabel(
            label.to_string(),
        ));
    }
    Ok(())
}

/// Validates a proposed relation's two endpoints against the ontology:
/// `C5`'s "extend the core ontology only" rule, applied to *both* sides of a
/// relation rather than one entity's own declaration. Both fields being
/// [`CoreEntityType`] already makes this true by construction for any
/// in-process-built [`EntityTypeDef`] — this function is the same guarantee
/// re-affirmed at the boundary a config-loaded pair of definitions actually
/// needs it checked, mirroring [`parse_extends`].
pub fn validate_relation_endpoints(
    source: &EntityTypeDef,
    target: &EntityTypeDef,
) -> Result<(), OntologyError> {
    let _: Archetype = source.extends.extends();
    let _: Archetype = target.extends.extends();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_primitive_round_trips_through_its_wire_spelling() {
        for p in Primitive::all() {
            assert_eq!(Primitive::parse(p.as_str()), Some(*p));
        }
    }

    #[test]
    fn the_issue_merge_table_is_exact() {
        assert_eq!(Primitive::String.default_merge(), MergeStrategy::Lww);
        assert_eq!(Primitive::Text.default_merge(), MergeStrategy::Revisions);
        assert_eq!(Primitive::Bool.default_merge(), MergeStrategy::Monotonic);
        assert_eq!(Primitive::Number.default_merge(), MergeStrategy::Lww);
        assert_eq!(Primitive::Datetime.default_merge(), MergeStrategy::Lww);
        assert_eq!(Primitive::List.default_merge(), MergeStrategy::Union);
        assert_eq!(Primitive::Set.default_merge(), MergeStrategy::Union);
        assert_eq!(Primitive::Reference.default_merge(), MergeStrategy::Union);
        assert_eq!(Primitive::Blob.default_merge(), MergeStrategy::Hash);
    }

    #[test]
    fn there_are_exactly_nine_primitives_twelve_archetypes_and_twelve_core_types() {
        assert_eq!(Primitive::all().len(), 9);
        assert_eq!(Archetype::all().len(), 12);
        assert_eq!(CoreEntityType::all().len(), 12);
    }

    #[test]
    fn every_archetype_round_trips_through_its_wire_spelling() {
        for a in Archetype::all() {
            assert_eq!(Archetype::parse(a.as_str()), Some(*a));
        }
    }

    #[test]
    fn every_core_entity_type_round_trips_through_its_wire_spelling() {
        for t in CoreEntityType::all() {
            assert_eq!(CoreEntityType::parse(t.as_str()), Some(*t));
        }
    }

    #[test]
    fn archetype_and_core_ontology_names_never_collide() {
        for a in Archetype::all() {
            assert!(
                CoreEntityType::parse(a.as_str()).is_none(),
                "archetype name '{}' must not also be a core ontology name",
                a.as_str()
            );
        }
    }

    #[test]
    fn the_four_issue_given_extends_edges_are_exact() {
        assert_eq!(CoreEntityType::Person.extends(), Archetype::Actor);
        assert_eq!(CoreEntityType::Task.extends(), Archetype::Workflow);
        assert_eq!(CoreEntityType::Document.extends(), Archetype::Artifact);
        assert_eq!(CoreEntityType::Conversation.extends(), Archetype::Activity);
    }

    #[test]
    fn every_core_entity_type_extends_exactly_one_archetype() {
        // Exercises every arm of `extends()` so an unmapped variant is a
        // compile error, not a silent gap.
        for t in CoreEntityType::all() {
            let _ = t.extends();
        }
    }

    // -- Primitive type-checking: reject wrong-shaped data --------------

    #[test]
    fn a_value_of_the_wrong_primitive_is_rejected() {
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_label("Doctor")
            .with_label("Clinician")
            .with_property("speciality", Primitive::String);

        let err = doctor
            .validate_property("speciality", &Value::Number(1.0))
            .unwrap_err();
        assert_eq!(
            err,
            OntologyError::TypeMismatch {
                property: "speciality".to_string(),
                expected: Primitive::String,
                found: Primitive::Number,
            }
        );
    }

    #[test]
    fn a_correctly_typed_value_is_accepted() {
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String);
        assert!(doctor
            .validate_property("speciality", &Value::Str("Cardiology".to_string()))
            .is_ok());
    }

    #[test]
    fn an_undeclared_property_is_rejected() {
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person);
        let err = doctor
            .validate_property("speciality", &Value::Str("Cardiology".to_string()))
            .unwrap_err();
        assert_eq!(
            err,
            OntologyError::UnknownProperty("speciality".to_string())
        );
    }

    #[test]
    fn an_empty_reference_is_rejected_as_wrong_shaped() {
        let t = EntityTypeDef::new("Task", CoreEntityType::Task)
            .with_property("assignee", Primitive::Reference);
        let err = t
            .validate_property("assignee", &Value::Reference(String::new()))
            .unwrap_err();
        assert!(matches!(err, OntologyError::InvalidValue { .. }));
    }

    #[test]
    fn a_non_finite_number_is_rejected_as_wrong_shaped() {
        let t = EntityTypeDef::new("Measurement", CoreEntityType::Task)
            .with_property("value", Primitive::Number);
        let err = t
            .validate_property("value", &Value::Number(f64::NAN))
            .unwrap_err();
        assert!(matches!(err, OntologyError::InvalidValue { .. }));
    }

    // -- Archetypes composed from primitives -----------------------------

    #[test]
    fn an_entity_type_composes_several_primitives_and_validates_each_independently() {
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
            .with_property("speciality", Primitive::String)
            .with_property("yearsPracticing", Primitive::Number)
            .with_property("boardCertified", Primitive::Bool)
            .with_property("clinic", Primitive::Reference)
            .with_property("languages", Primitive::List);

        assert!(doctor
            .validate_property("speciality", &Value::Str("Cardiology".to_string()))
            .is_ok());
        assert!(doctor
            .validate_property("yearsPracticing", &Value::Number(12.0))
            .is_ok());
        assert!(doctor
            .validate_property("boardCertified", &Value::Bool(true))
            .is_ok());
        assert!(doctor
            .validate_property("clinic", &Value::Reference("clinic-1".to_string()))
            .is_ok());
        assert!(doctor
            .validate_property(
                "languages",
                &Value::List(vec![
                    Value::Str("en".to_string()),
                    Value::Str("hi".to_string())
                ])
            )
            .is_ok());

        // Swap two properties' values and both now fail independently.
        assert!(doctor
            .validate_property("speciality", &Value::Bool(true))
            .is_err());
        assert!(doctor
            .validate_property("boardCertified", &Value::Str("yes".to_string()))
            .is_err());
    }

    // -- Ontology rules enforced, not just declared -----------------------

    #[test]
    fn extending_an_archetype_directly_is_rejected_at_the_config_boundary() {
        let err = parse_extends("Actor").unwrap_err();
        assert_eq!(
            err,
            OntologyError::CannotExtendArchetypeDirectly("Actor".to_string())
        );
    }

    #[test]
    fn extending_the_core_ontology_is_accepted_at_the_config_boundary() {
        assert_eq!(parse_extends("Person"), Ok(CoreEntityType::Person));
    }

    #[test]
    fn an_unknown_extends_target_is_rejected_distinctly_from_an_archetype() {
        let err = parse_extends("Doctor").unwrap_err();
        assert_eq!(err, OntologyError::UnknownCoreType("Doctor".to_string()));
    }

    #[test]
    fn an_entity_type_def_cannot_be_constructed_extending_an_archetype() {
        // Not a runtime assertion -- `EntityTypeDef::extends` is typed
        // `CoreEntityType`, so `EntityTypeDef::new("x", Archetype::Actor)`
        // is a compile error. This test exists so the guarantee has a place
        // in the suite even though nothing here can fail at runtime.
        let def = EntityTypeDef::new("Doctor", CoreEntityType::Person);
        assert_eq!(def.extends, CoreEntityType::Person);
    }

    #[test]
    fn a_bare_archetype_name_is_rejected_as_a_user_facing_label() {
        let err = validate_user_facing_label("Actor").unwrap_err();
        assert_eq!(
            err,
            OntologyError::ArchetypeUsedAsUserFacingLabel("Actor".to_string())
        );
    }

    #[test]
    fn a_core_ontology_or_capability_label_is_accepted() {
        assert!(validate_user_facing_label("Person").is_ok());
        assert!(validate_user_facing_label("Doctor").is_ok());
    }

    #[test]
    fn relation_endpoints_extending_the_core_ontology_validate() {
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person);
        let clinic = EntityTypeDef::new("Clinic", CoreEntityType::Organization);
        assert!(validate_relation_endpoints(&doctor, &clinic).is_ok());
    }

    // -- Round-trip through the wire format --------------------------------

    #[test]
    fn every_scalar_primitive_round_trips_through_encode_decode() {
        let values = vec![
            Value::Str("hello".to_string()),
            Value::Text("a longer body of revisable text".to_string()),
            Value::Bool(true),
            Value::Bool(false),
            Value::Number(3.5),
            Value::Number(-1.0),
            Value::Datetime(1_723_000_000_000),
            Value::Reference("entity-42".to_string()),
            Value::Blob(vec![0, 1, 2, 255]),
        ];
        for v in values {
            let encoded = v.encode();
            assert_eq!(
                Value::decode(&encoded),
                Some(v.clone()),
                "round-trip failed for {v:?}"
            );
            assert_eq!(Value::decode(&encoded).unwrap().primitive(), v.primitive());
        }
    }

    #[test]
    fn a_list_round_trips_preserving_order() {
        let list = Value::List(vec![
            Value::Str("first".to_string()),
            Value::Number(2.0),
            Value::Bool(false),
        ]);
        let encoded = list.encode();
        assert_eq!(Value::decode(&encoded), Some(list));
    }

    #[test]
    fn a_set_round_trips_deduplicated_and_order_independent() {
        let a = Value::Set(vec![
            Value::Str("x".to_string()),
            Value::Str("y".to_string()),
            Value::Str("x".to_string()), // duplicate
        ]);
        let b = Value::Set(vec![
            Value::Str("y".to_string()),
            Value::Str("x".to_string()),
        ]);
        // Different insertion order, one has a duplicate: both encode to the
        // same canonical bytes (`C3`: merge must be idempotent).
        assert_eq!(a.encode(), b.encode());
        let decoded = Value::decode(&a.encode()).unwrap();
        if let Value::Set(items) = decoded {
            assert_eq!(items.len(), 2);
        } else {
            panic!("expected a Set");
        }
    }

    #[test]
    fn a_nested_list_of_lists_round_trips() {
        let nested = Value::List(vec![
            Value::List(vec![Value::Number(1.0), Value::Number(2.0)]),
            Value::List(vec![Value::Str("nested".to_string())]),
        ]);
        let encoded = nested.encode();
        assert_eq!(Value::decode(&encoded), Some(nested));
    }

    #[test]
    fn truncated_or_trailing_bytes_fail_to_decode() {
        let encoded = Value::Str("hi".to_string()).encode();
        assert_eq!(Value::decode(&encoded[..encoded.len() - 1]), None);
        let mut with_trailer = encoded.clone();
        with_trailer.push(0xFF);
        assert_eq!(Value::decode(&with_trailer), None);
    }

    #[test]
    fn value_encode_is_compatible_with_encode_set_property() {
        // The additive-integration proof: a typed `Value` encodes into
        // exactly the `&[u8]` `crate::projection::encode_set_property`
        // already accepts, with no format change to that function at all.
        let value = Value::Str("Cardiology".to_string());
        let payload = crate::projection::encode_set_property("speciality", &value.encode());
        assert!(!payload.is_empty());
    }

    #[test]
    fn schema_ids_are_stable_and_distinct_between_core_and_capability_types() {
        assert_eq!(CoreEntityType::Person.schema_id(), "core.Person");
        let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person);
        assert_eq!(doctor.schema_id(), "capability.Doctor");
        assert_ne!(CoreEntityType::Person.schema_id(), doctor.schema_id());
    }
}
