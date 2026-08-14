//! `#1295`: the capability-facing runtime API surface. Five entry points and
//! nothing else.
//!
//! # Why this exists
//!
//! `I2`/`I4` say a capability must not create durable storage and that all
//! durable state originates from the runtime — today nothing *structurally*
//! prevented that beyond review. [`CapabilityApi`] is the fix: a capability
//! built against this type alone cannot reach [`crate::runtime::OperationLog`],
//! [`crate::content::ContentStore`], or [`crate::signing`] — there is no path
//! from here to any of them except through the five methods below, each of
//! which returns an opaque result rather than a handle to the thing that
//! produced it. `notes::NotesCapability`'s own conformance test already
//! proves it never reaches the filesystem directly, for one capability, by
//! convention; this module is the same property enforced by the type system
//! for every capability built after it, because `CapabilityApi` is the only
//! door.
//!
//! # The five functions, and where each one stands
//!
//! | Function | Status | Backed by |
//! |---|---|---|
//! | [`CapabilityApi::create_operation`] | **Real** | [`crate::runtime::Runtime::emit_operation_ex`] |
//! | [`CapabilityApi::attach_content`] | **Real** | [`crate::runtime::Runtime::attach_content`] |
//! | [`CapabilityApi::query_projection`] | **Real** | [`crate::runtime::Runtime::query_projection`] |
//! | [`CapabilityApi::emit_event`] | **Real** | [`crate::event::EventBus`] |
//! | [`CapabilityApi::instantiate_context`] | **Stubbed** | nothing — always `Err` |
//!
//! `instantiate_context` is the one function this module declares but does
//! not implement. `#1295` is blocked by `#1197` (Context Runtime), and
//! `#1197`'s actual scope — a context hypergraph, `LinkContent` /
//! `UnlinkContent` / `DestroyContent` end-to-end semantics, "what survives
//! elsewhere" computation for any destructive action, context templates
//! shipped by capabilities — has no substrate in this crate yet beyond the
//! three [`crate::verb::Verb`] variants (`CreateContext`, `LinkContext`,
//! `UnlinkContext`) declared and unimplemented on the wire format. A stub
//! that quietly created a bare entity and called it a "context" would satisfy
//! the type signature while lying about the guarantee `#1197` exists to
//! provide (that uninstalling a capability never deletes the contexts it
//! created, and that the runtime can compute what survives when content is
//! unlinked from one). Better to fail loudly with
//! [`CapabilityApiError::NotImplemented`] than to ship a context that only
//! *looks* like the real thing.
//!
//! # What is honestly still missing
//!
//! [`CapabilityApi::query_projection`] does not (cannot yet) isolate one
//! capability's data from another's — [`crate::projection::EntityGraphProjection`]
//! is deliberately shared across every capability that emits entity-graph
//! verbs (`#1195`'s own proof depends on that). Per-capability query
//! isolation is part of what `#1197`'s context boundary is supposed to
//! provide once it lands; until then, `query_projection` is real and useful,
//! but not yet the isolation boundary the design doc's endgame describes.

use crate::content::ContentId;
use crate::event::CapabilityEvent;
use crate::runtime::{OperationRequest, Projection, Runtime, RuntimeApiError};
use crate::verb::Verb;

/// What a capability names the operation it is creating: one of the
/// nineteen fixed verbs (`#1194`'s scope table), or a capability's own
/// free-form vocabulary (`"note.create"`) for one that has not adopted the
/// entity/property graph model. Both share the wire's one `kind` field —
/// see [`crate::verb::Verb`]'s module doc.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OperationKind<'a> {
    Verb(Verb),
    Custom(&'a str),
}

impl<'a> OperationKind<'a> {
    fn as_wire(&self) -> &str {
        match self {
            Self::Verb(v) => v.as_str(),
            Self::Custom(s) => s,
        }
    }
}

/// Everything [`CapabilityApi::create_operation`] needs beyond the
/// capability id, which is bound once at [`CapabilityApi::new`] and cannot be
/// overridden per call — a capability cannot emit an operation under another
/// capability's name.
#[derive(Clone, Copy, Debug)]
pub struct CreateOperationRequest<'a> {
    pub kind: OperationKind<'a>,
    /// `entityId` (design §3.1). Empty string for an operation that does not
    /// touch the entity/property graph.
    pub entity_id: &'a str,
    /// `contextIds[]` (design §3.1). Empty until `#1197` lands.
    pub context_ids: &'a [&'a str],
    /// `schemaId` (design §5.5). Empty until a capability declares a real
    /// schema fingerprint — `#1196`'s job, not this one's.
    pub schema_id: &'a str,
    /// This operation's causal parent, when it has one.
    pub parent_operation_id: Option<&'a str>,
    /// Small, inline structural arguments — a note's title, a property's new
    /// value. Not routed through the content store; see
    /// [`crate::runtime::Operation::payload`]'s doc for the line between this
    /// and `content`.
    pub payload: &'a [u8],
    /// When set, stored in the content store first and linked into the
    /// operation as a [`ContentId`] — the capability never inlines large
    /// data directly into `payload`.
    pub content: Option<&'a [u8]>,
    pub recorded_at_ms: u64,
}

impl<'a> CreateOperationRequest<'a> {
    /// The common case: a verb-based operation with no context, schema, or
    /// parent yet. `entity_id`/`payload` still need setting for anything but
    /// a bare marker operation.
    pub fn verb(kind: Verb, recorded_at_ms: u64) -> Self {
        Self {
            kind: OperationKind::Verb(kind),
            entity_id: "",
            context_ids: &[],
            schema_id: "",
            parent_operation_id: None,
            payload: &[],
            content: None,
            recorded_at_ms,
        }
    }

    /// As [`Self::verb`], for a capability using its own free-form `kind`
    /// string rather than one of the nineteen fixed verbs.
    pub fn custom(kind: &'a str, recorded_at_ms: u64) -> Self {
        Self {
            kind: OperationKind::Custom(kind),
            entity_id: "",
            context_ids: &[],
            schema_id: "",
            parent_operation_id: None,
            payload: &[],
            content: None,
            recorded_at_ms,
        }
    }
}

/// What [`CapabilityApi::create_operation`] hands back. Deliberately not
/// [`crate::runtime::Operation`] itself — that type carries `signature`,
/// `device_id`, and `version_vector`, none of which a capability needs and
/// all of which are exactly the kind of storage-shape detail this surface
/// exists to keep a capability from depending on.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OperationReceipt {
    /// Citable as a future operation's `parent_operation_id`.
    pub operation_id: String,
    /// This device's local ordering position. Not a cross-device fact —
    /// `#1194`'s module doc: multi-device merge is Phase 3's job.
    pub seq: u64,
    /// Set when `content` was provided and stored.
    pub content_id: Option<ContentId>,
}

/// An opaque handle to an instantiated context. No method on this type
/// returns it today — [`CapabilityApi::instantiate_context`] is stubbed —
/// but the shape is declared now (per `#1295`'s scope: "define the five
/// entry points precisely: signatures, error types, and what each
/// guarantees") so the eventual `#1197` implementation is not a breaking
/// change to this surface.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ContextId(pub String);

/// Why a call against [`CapabilityApi`] failed. Deliberately narrower than
/// [`RuntimeApiError`]: no [`crate::runtime::OperationLogError`] variant, no
/// [`crate::content::ContentStoreError`] variant, reaches a capability —
/// those name I/O paths and on-disk shapes a capability must not be able to
/// depend on (`#1295`'s "a capability that learns it is querying SQL will
/// eventually depend on SQL", generalized to every storage detail, not only
/// SQL).
#[derive(Debug)]
pub enum CapabilityApiError {
    /// The operation could not be durably recorded. The message is a display
    /// string for logging/debugging — a capability must not pattern-match
    /// it to make a decision, since its exact wording is not part of this
    /// surface's contract.
    Operation(String),
    /// The function exists on the five-function surface but is not
    /// implemented for the reason stated in the message. Currently only
    /// [`CapabilityApi::instantiate_context`] returns this.
    NotImplemented(&'static str),
}

impl std::fmt::Display for CapabilityApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Operation(m) => write!(f, "{m}"),
            Self::NotImplemented(what) => write!(f, "{what}"),
        }
    }
}

impl std::error::Error for CapabilityApiError {}

impl From<RuntimeApiError> for CapabilityApiError {
    fn from(e: RuntimeApiError) -> Self {
        match e {
            RuntimeApiError::OutOfScope(what) => Self::NotImplemented(what),
            other => Self::Operation(other.to_string()),
        }
    }
}

/// The only door. `#1295`: *"a capability never knows where data lives. It
/// receives a small, fixed surface and nothing else."* `C5`/`I2`/`I4`: this
/// type holds nothing durable of its own — its only fields are a runtime
/// reference and the capability's own id, bound once at construction so a
/// capability cannot emit an operation, or an event, under another
/// capability's name.
pub struct CapabilityApi<'a> {
    runtime: &'a Runtime,
    capability_id: String,
}

impl<'a> CapabilityApi<'a> {
    /// Binds this handle to one capability id for its whole lifetime. A
    /// capability author calls this once (typically in its own
    /// `MyCapability::new`, the same pattern [`crate::notes::NotesCapability`]
    /// already follows) and keeps the result — every subsequent call is
    /// stamped with `capability_id`, never a caller-supplied one.
    pub fn new(runtime: &'a Runtime, capability_id: impl Into<String>) -> Self {
        Self {
            runtime,
            capability_id: capability_id.into(),
        }
    }

    pub fn capability_id(&self) -> &str {
        &self.capability_id
    }

    /// Appends one durable operation to the log, under this handle's bound
    /// capability id. The only write path a capability has onto durable
    /// state — there is no `attach_content` call that also appends an
    /// operation on its own; a capability that wants stored content
    /// reachable from the log sets `content` on this request rather than
    /// calling [`Self::attach_content`] first (though it may, if it needs a
    /// [`ContentId`] before it knows what operation will reference it).
    ///
    /// **Guarantee**: on `Ok`, the operation is durable and signed — it has
    /// already passed the ingest-time signature check `#1194`'s module doc
    /// describes — before this call returns.
    pub fn create_operation(
        &self,
        req: CreateOperationRequest<'_>,
    ) -> Result<OperationReceipt, CapabilityApiError> {
        let op = self.runtime.emit_operation_ex(OperationRequest {
            capability: &self.capability_id,
            kind: req.kind.as_wire(),
            payload: req.payload,
            recorded_at_ms: req.recorded_at_ms,
            entity_id: req.entity_id,
            parent_operation_id: req.parent_operation_id,
            context_ids: req.context_ids,
            schema_id: req.schema_id,
            content: req.content,
        })?;
        Ok(OperationReceipt {
            operation_id: op.operation_id,
            seq: op.seq,
            content_id: op.content_id,
        })
    }

    /// Stores `bytes` in the content store, content-addressed, and returns
    /// only the resulting [`ContentId`] — never a file path, never key
    /// material (there is none yet; see [`crate::content`]'s module doc for
    /// the encryption gap this leaves, which is Phase 1's job, not this
    /// surface's). `#1295`'s scope, verbatim: *"the capability never sees
    /// key material or a file path."*
    ///
    /// This alone does not make the content reachable from the operation
    /// log — pass it as `content` on a [`CreateOperationRequest`] (typically
    /// with `kind: OperationKind::Verb(Verb::CreateContent)`) for that, or
    /// call this first and thread the id through if the operation that will
    /// reference it is not known yet.
    pub fn attach_content(&self, bytes: &[u8]) -> Result<ContentId, CapabilityApiError> {
        Ok(self.runtime.attach_content(bytes)?)
    }

    /// Rebuilds and returns a read-model of type `P`, always from a fresh
    /// replay of the log — never a cache this call could have returned
    /// stale. **Guarantee**: `query_projection` does not leak the
    /// projection's storage shape — `P` is folded in memory from
    /// [`crate::runtime::Operation`] values; there is no SQL, no query
    /// language, and no way for a capability calling this to learn or depend
    /// on how (or whether) a projection is ever cached or indexed
    /// internally.
    ///
    /// **Known gap** (see the module doc): this does not yet isolate one
    /// capability's projection data from another's. A capability holding a
    /// `CapabilityApi` can request any [`Projection`] type in the crate,
    /// including one fed by other capabilities' operations — the
    /// per-capability isolation `#1197`'s context boundary is meant to add
    /// does not exist yet.
    pub fn query_projection<P: Projection>(&self) -> Result<P, CapabilityApiError> {
        Ok(self.runtime.query_projection::<P>()?)
    }

    /// Publishes one in-process, non-durable event. **Guarantee, stated
    /// explicitly per `#1295`'s scope**: this is *not* a persistence path.
    /// Nothing published here is ever written to the operation log, ever
    /// replayed, or survives a process restart — see [`crate::event`]'s
    /// module doc for exactly what "in-process and non-durable" means
    /// mechanically. A capability that needs the event to still be true
    /// tomorrow, or on another device, must call [`Self::create_operation`]
    /// instead.
    ///
    /// This call cannot fail — a publish with zero live subscribers is a
    /// normal outcome (nobody is listening right now), not an error.
    pub fn emit_event(&self, topic: &str, payload: &[u8]) {
        self.runtime.publish_event(CapabilityEvent {
            capability: self.capability_id.clone(),
            topic: topic.to_string(),
            payload: payload.to_vec(),
        });
    }

    /// Physically and durably destroys a piece of content — condition 8 of
    /// `#1311` (`#1217`). Deliberately **not** one of `#1295`'s original five
    /// functions: [`Self::create_operation`] alone cannot honestly implement
    /// this (see [`Runtime::destroy_content`]'s doc for why an append-only
    /// log cannot make its own past bytes disappear by appending to itself),
    /// so per `C5`'s own governing question this is the generic primitive the
    /// runtime was missing, added once here rather than worked around by any
    /// one capability.
    ///
    /// **Guarantee**: on `Ok`, the content's bytes have already been
    /// overwritten and removed from disk, and a `DestroyContent` operation
    /// naming the (now-destroyed) content id is durable in the log — both
    /// steps completed, in that order, before this call returns. A capability
    /// never sees a file path or key material to do this itself; this is the
    /// only door.
    pub fn destroy_content(
        &self,
        content_id: ContentId,
        entity_id: &str,
        recorded_at_ms: u64,
    ) -> Result<OperationReceipt, CapabilityApiError> {
        let op = self.runtime.destroy_content(
            &self.capability_id,
            content_id,
            entity_id,
            recorded_at_ms,
        )?;
        Ok(OperationReceipt {
            operation_id: op.operation_id,
            seq: op.seq,
            content_id: op.content_id,
        })
    }

    /// **Stubbed.** `#1295` is blocked by `#1197` (Context Runtime), and the
    /// substrate `#1197` actually requires — the context hypergraph,
    /// `LinkContent`/`UnlinkContent`/`DestroyContent` end-to-end semantics,
    /// "what survives elsewhere" computation, context templates — does not
    /// exist in this crate yet. This always returns
    /// [`CapabilityApiError::NotImplemented`] rather than faking a context
    /// with a bare entity, which would satisfy the type signature while
    /// lying about the guarantee `#1197` exists to provide. See this
    /// module's doc for the full reasoning.
    pub fn instantiate_context(
        &self,
        _template_id: &str,
        _recorded_at_ms: u64,
    ) -> Result<ContextId, CapabilityApiError> {
        Err(CapabilityApiError::NotImplemented(
            "instantiate_context is blocked on #1197 (Context Runtime): the context \
             hypergraph and LinkContent/UnlinkContent/DestroyContent semantics do not \
             exist yet, so this surface cannot yet let a capability organize data into \
             a user-owned context",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::budget::ResourceBudget;
    use crate::projection::{encode_relation, encode_set_property, EntityGraphProjection};
    use crate::runtime::Runtime;

    fn temp_log_path(name: &str) -> std::path::PathBuf {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("airo_mind_capability_api_test_{name}_{unique}.log"))
    }

    fn cleanup(path: &std::path::Path) {
        let _ = std::fs::remove_file(path);
        let mut device_id = path.file_name().unwrap().to_string_lossy().into_owned();
        device_id.push_str(".device_id");
        let _ = std::fs::remove_file(path.with_file_name(device_id));
        let mut content = path.file_name().unwrap().to_string_lossy().into_owned();
        content.push_str(".content");
        let _ = std::fs::remove_dir_all(path.with_file_name(content));
    }

    /// A fake minimal capability, built to prove `CapabilityApi` is usable
    /// end to end without reaching into `crate::runtime` or
    /// `crate::projection` directly. It holds nothing but the handle, the
    /// same `I2`/`I4` discipline `NotesCapability` follows.
    struct FakeContactCapability<'a> {
        api: CapabilityApi<'a>,
    }

    impl<'a> FakeContactCapability<'a> {
        const CAPABILITY_ID: &'static str = "fake_contacts";

        fn new(runtime: &'a Runtime) -> Self {
            Self {
                api: CapabilityApi::new(runtime, Self::CAPABILITY_ID),
            }
        }

        fn create_contact(
            &self,
            id: &str,
            name: &str,
            recorded_at_ms: u64,
        ) -> Result<OperationReceipt, CapabilityApiError> {
            let mut req = CreateOperationRequest::verb(Verb::CreateEntity, recorded_at_ms);
            req.entity_id = id;
            req.payload = b"Contact";
            let create_receipt = self.api.create_operation(req)?;

            let mut set_name = CreateOperationRequest::verb(Verb::SetProperty, recorded_at_ms + 1);
            set_name.entity_id = id;
            let encoded = encode_set_property("name", name.as_bytes());
            set_name.payload = &encoded;
            self.api.create_operation(set_name)?;

            self.api.emit_event("contact.created", id.as_bytes());
            Ok(create_receipt)
        }

        fn link_contact(
            &self,
            from: &str,
            relation: &str,
            to: &str,
            recorded_at_ms: u64,
        ) -> Result<OperationReceipt, CapabilityApiError> {
            let mut req = CreateOperationRequest::verb(Verb::AddRelation, recorded_at_ms);
            req.entity_id = from;
            let encoded = encode_relation(relation, to);
            req.payload = &encoded;
            self.api.create_operation(req)
        }

        fn contacts(&self) -> Result<EntityGraphProjection, CapabilityApiError> {
            self.api.query_projection::<EntityGraphProjection>()
        }
    }

    /// The conformance test `#1295` asks for: a fake capability using
    /// *only* `CapabilityApi` writes an operation, reads it back via a
    /// projection, and the round trip holds.
    #[test]
    fn a_fake_capability_using_only_the_capability_api_writes_and_reads_back_through_a_projection()
    {
        let path = temp_log_path("roundtrip");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let contacts = FakeContactCapability::new(&runtime);

        contacts
            .create_contact("c1", "Ada Lovelace", 1_000)
            .unwrap();
        contacts.create_contact("c2", "Alan Turing", 2_000).unwrap();
        contacts.link_contact("c1", "knows", "c2", 3_000).unwrap();

        let graph = contacts.contacts().unwrap();
        assert_eq!(graph.len(), 2);
        let ada = graph.get("c1").unwrap();
        assert_eq!(ada.label, "Contact");
        assert_eq!(ada.properties.get("name").unwrap(), b"Ada Lovelace");
        assert!(ada
            .relations
            .contains(&("knows".to_string(), "c2".to_string())));

        // Independently, the underlying operation log actually holds these
        // durably -- not just visible through the one projection type this
        // test happened to query.
        assert_eq!(runtime.replay().unwrap().len(), 5);

        cleanup(&path);
    }

    /// Deleting the in-memory projection and rebuilding from the log alone
    /// must reproduce the same state -- `C4` proven through the capability
    /// surface, not only through `Runtime`/`EntityGraphProjection` directly.
    #[test]
    fn projection_state_survives_deletion_and_rebuild_through_the_capability_api() {
        let path = temp_log_path("survive");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let contacts = FakeContactCapability::new(&runtime);
        contacts.create_contact("c1", "Grace Hopper", 1).unwrap();

        let before = contacts.contacts().unwrap();
        drop(before);

        let after = contacts.contacts().unwrap();
        assert_eq!(
            after.get("c1").unwrap().properties.get("name").unwrap(),
            b"Grace Hopper"
        );

        cleanup(&path);
    }

    /// `create_operation` stores large content out of line and links only
    /// the `ContentId` into the operation -- proven through the capability
    /// surface's own request/response types, not `crate::runtime::Operation`.
    #[test]
    fn create_operation_with_content_round_trips_through_attach_and_read() {
        let path = temp_log_path("content");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "fake_docs");

        let mut req = CreateOperationRequest::verb(Verb::CreateContent, 1);
        req.entity_id = "doc-1";
        req.content = Some(b"a whole document's bytes");
        let receipt = api.create_operation(req).unwrap();

        let content_id = receipt
            .content_id
            .expect("CreateContent must attach a content id");
        // The capability never sees a path -- only the id it can hand back
        // to `attach_content`'s sibling read path on `Runtime` (content
        // reading is intentionally not part of the five-function surface;
        // a capability threads the id it needs into further operations or
        // its own projection instead). This assertion goes through
        // `Runtime` only to prove the bytes are really there -- the
        // capability itself never does this.
        assert_eq!(
            runtime.read_content(&content_id).unwrap().unwrap(),
            b"a whole document's bytes"
        );

        cleanup(&path);
    }

    /// `attach_content` alone: a capability that needs a `ContentId` before
    /// it knows what operation will reference it.
    #[test]
    fn attach_content_returns_only_an_opaque_content_id() {
        let path = temp_log_path("attach");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "fake_docs");
        let id = api.attach_content(b"pre-attached bytes").unwrap();
        assert_eq!(
            runtime.read_content(&id).unwrap().unwrap(),
            b"pre-attached bytes"
        );
        cleanup(&path);
    }

    /// `emit_event` is real: a subscriber registered on the runtime observes
    /// what the capability publishes, in-process.
    #[test]
    fn emit_event_reaches_a_runtime_level_subscriber() {
        let path = temp_log_path("event");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let rx = runtime.subscribe_events();
        let api = CapabilityApi::new(&runtime, "fake_contacts");

        api.emit_event("contact.created", b"c1");

        let event = rx.recv().unwrap();
        assert_eq!(event.capability, "fake_contacts");
        assert_eq!(event.topic, "contact.created");
        assert_eq!(event.payload, b"c1");

        cleanup(&path);
    }

    /// `emit_event` is explicitly not a persistence path: publishing does
    /// not append anything to the operation log.
    #[test]
    fn emit_event_never_touches_the_operation_log() {
        let path = temp_log_path("event_not_durable");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "fake_contacts");
        api.emit_event("t", b"payload");
        assert!(runtime.replay().unwrap().is_empty());
        cleanup(&path);
    }

    /// `instantiate_context` is honestly stubbed, not faked -- calling it
    /// always fails with a message naming exactly what is missing.
    #[test]
    fn instantiate_context_is_explicitly_not_implemented() {
        let path = temp_log_path("context_stub");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "fake_contacts");
        let err = api.instantiate_context("some-template", 1).unwrap_err();
        assert!(matches!(err, CapabilityApiError::NotImplemented(_)));
        assert!(err.to_string().contains("#1197"));
        cleanup(&path);
    }

    /// A capability cannot spoof another capability's id -- `capability_id`
    /// is bound once at construction and every subsequent operation is
    /// stamped with it, never a caller-supplied value.
    #[test]
    fn every_operation_is_stamped_with_the_bound_capability_id_not_a_caller_supplied_one() {
        let path = temp_log_path("capability_id_bound");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "honest_capability");

        let req = CreateOperationRequest::verb(Verb::CreateEntity, 1);
        api.create_operation(req).unwrap();

        let ops = runtime.replay().unwrap();
        assert_eq!(ops.len(), 1);
        assert_eq!(ops[0].capability, "honest_capability");

        cleanup(&path);
    }

    /// `C5`/`I2`/`I4`: this type holds nothing durable of its own -- its
    /// only fields are the runtime reference and the bound capability id
    /// string, the same shape discipline `NotesCapability`'s own test
    /// enforces for itself (there, `size_of` proves a single pointer; here
    /// the id is owned `String` rather than `&'static str`, so the
    /// equivalent proof is structural: grep, not `size_of`).
    #[test]
    fn the_capability_api_never_touches_the_filesystem_directly() {
        let source = include_str!("capability_api.rs");
        let production_code = source.split("#[cfg(test)]").next().unwrap();
        assert!(
            !production_code.contains("std::fs"),
            "CapabilityApi must reach storage only through Runtime's own methods"
        );
    }

    /// A capability using a free-form `kind` string (not one of the
    /// nineteen fixed verbs) works the same way `NotesCapability` already
    /// relies on for `Runtime::emit_operation`.
    #[test]
    fn custom_kind_operations_work_the_same_as_verb_operations() {
        let path = temp_log_path("custom_kind");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let api = CapabilityApi::new(&runtime, "fake_freeform");

        let mut req = CreateOperationRequest::custom("freeform.thing", 1);
        req.payload = b"hello";
        let receipt = api.create_operation(req).unwrap();
        assert!(!receipt.operation_id.is_empty());

        let ops = runtime.replay().unwrap();
        assert_eq!(ops[0].kind, "freeform.thing");
        assert_eq!(
            ops[0].verb(),
            None,
            "a free-form kind is not one of the fixed verbs"
        );

        cleanup(&path);
    }
}
