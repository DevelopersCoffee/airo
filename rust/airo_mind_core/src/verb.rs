//! The fixed verb set. `#1194`'s scope table, restated as a type instead of a
//! bag of strings.
//!
//! Design doc §3.2: *"There is no `Delete`. Deletion is ambiguous and the
//! ambiguity is dangerous."* Content is destroyed (`DestroyContent`, and only
//! by crypto-shredding — Phase 1/Vault's job, not this one's); entities and
//! relations are only ever created, set, added, or removed as **links** —
//! `RemoveRelation` removes a relation, never the entities it joined.
//!
//! This is the runtime-level vocabulary. A capability's own domain vocabulary
//! (`"note.create"`, in [`crate::notes`]) stays free-form on the wire — `C5`:
//! *"the runtime knows no domains"* — but every capability that wants to
//! participate in the entity/context graph the design describes emits one of
//! these, and [`Runtime::emit_verb_operation`](crate::runtime::Runtime::emit_verb_operation)
//! is the seam that requires it.

/// One runtime verb, exactly the set `#1194` scopes. `as_str`/`from_str`
/// round-trip through the wire format's `kind` field, so a verb-based
/// operation and a capability's free-form `kind` string share one encoding —
/// there is no second field to keep in sync.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Verb {
    CreateEntity,
    SetProperty,
    AddRelation,
    RemoveRelation,
    CreateContent,
    LinkContent,
    UnlinkContent,
    DestroyContent,
    CreateContext,
    LinkContext,
    UnlinkContext,
    InstallPack,
    UpgradePack,
    RemovePack,
    EnablePack,
    DisablePack,
    AuthorizeDevice,
    RevokeDevice,
    RevokeContentKey,
}

/// Every verb, in the order the design doc lists them. Exhaustive on purpose:
/// [`Verb::all`], the round-trip test, and any future exhaustiveness check
/// all read from one place.
pub const ALL_VERBS: &[Verb] = &[
    Verb::CreateEntity,
    Verb::SetProperty,
    Verb::AddRelation,
    Verb::RemoveRelation,
    Verb::CreateContent,
    Verb::LinkContent,
    Verb::UnlinkContent,
    Verb::DestroyContent,
    Verb::CreateContext,
    Verb::LinkContext,
    Verb::UnlinkContext,
    Verb::InstallPack,
    Verb::UpgradePack,
    Verb::RemovePack,
    Verb::EnablePack,
    Verb::DisablePack,
    Verb::AuthorizeDevice,
    Verb::RevokeDevice,
    Verb::RevokeContentKey,
];

impl Verb {
    pub fn all() -> &'static [Verb] {
        ALL_VERBS
    }

    /// The wire spelling. Matches the design doc's own `PascalCase` naming
    /// exactly, so a captured operation log reads the same on the wire as it
    /// does in the spec.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::CreateEntity => "CreateEntity",
            Self::SetProperty => "SetProperty",
            Self::AddRelation => "AddRelation",
            Self::RemoveRelation => "RemoveRelation",
            Self::CreateContent => "CreateContent",
            Self::LinkContent => "LinkContent",
            Self::UnlinkContent => "UnlinkContent",
            Self::DestroyContent => "DestroyContent",
            Self::CreateContext => "CreateContext",
            Self::LinkContext => "LinkContext",
            Self::UnlinkContext => "UnlinkContext",
            Self::InstallPack => "InstallPack",
            Self::UpgradePack => "UpgradePack",
            Self::RemovePack => "RemovePack",
            Self::EnablePack => "EnablePack",
            Self::DisablePack => "DisablePack",
            Self::AuthorizeDevice => "AuthorizeDevice",
            Self::RevokeDevice => "RevokeDevice",
            Self::RevokeContentKey => "RevokeContentKey",
        }
    }

    /// Parses a `kind` string back into a verb, when it is one. A capability
    /// emitting its own free-form `kind` (`"note.create"`) simply never
    /// matches here — that is not an error, it is a capability that has not
    /// opted into the formal graph vocabulary yet.
    pub fn parse_kind(s: &str) -> Option<Self> {
        ALL_VERBS.iter().copied().find(|v| v.as_str() == s)
    }

    /// Which primitive a verb mutates. Not load-bearing today, but the
    /// grouping the design doc's table (§3.2) already implies, made checkable
    /// rather than only visible in prose.
    pub fn primitive(self) -> VerbPrimitive {
        use Verb::*;
        match self {
            CreateEntity | SetProperty | AddRelation | RemoveRelation => VerbPrimitive::Entity,
            CreateContent | LinkContent | UnlinkContent | DestroyContent => VerbPrimitive::Content,
            CreateContext | LinkContext | UnlinkContext => VerbPrimitive::Context,
            InstallPack | UpgradePack | RemovePack | EnablePack | DisablePack => {
                VerbPrimitive::Capability
            }
            AuthorizeDevice | RevokeDevice | RevokeContentKey => VerbPrimitive::Vault,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VerbPrimitive {
    Entity,
    Content,
    Context,
    Capability,
    Vault,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `#1194`'s scope table, verbatim: nineteen names across five groups
    /// spelled out in the design doc. A verb added or removed here without a
    /// matching design-doc change is exactly the drift this test exists to
    /// catch.
    #[test]
    fn the_scope_table_has_exactly_nineteen_verbs() {
        assert_eq!(ALL_VERBS.len(), 19);
    }

    #[test]
    fn every_verb_round_trips_through_its_wire_spelling() {
        for verb in Verb::all() {
            let spelled = verb.as_str();
            assert_eq!(
                Verb::parse_kind(spelled),
                Some(*verb),
                "{spelled} did not round-trip"
            );
        }
    }

    #[test]
    fn an_unknown_kind_string_is_not_a_verb() {
        assert_eq!(Verb::parse_kind("note.create"), None);
        assert_eq!(Verb::parse_kind(""), None);
    }

    #[test]
    fn there_is_no_delete_verb() {
        assert!(
            Verb::all().iter().all(|v| v.as_str() != "Delete"),
            "design doc §3.2: deletion is ambiguous and intentionally absent"
        );
    }

    #[test]
    fn every_verb_names_the_primitive_it_mutates() {
        assert_eq!(Verb::CreateEntity.primitive(), VerbPrimitive::Entity);
        assert_eq!(Verb::DestroyContent.primitive(), VerbPrimitive::Content);
        assert_eq!(Verb::CreateContext.primitive(), VerbPrimitive::Context);
        assert_eq!(Verb::InstallPack.primitive(), VerbPrimitive::Capability);
        assert_eq!(Verb::RevokeContentKey.primitive(), VerbPrimitive::Vault);
    }
}
