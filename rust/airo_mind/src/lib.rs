#![forbid(unsafe_code)]
//! Airo Mind runtime.
//!
//! `forbid(unsafe_code)` is the point: "pure Rust, no FFI" is otherwise a
//! description rather than a property, and nothing enforces a description.
//!
//! The runtime understands seven primitives and no domain concepts:
//! Identity, Operation, Content, Context, Capability, Projection, Vault.
//!
//! Rules for every module in this crate:
//!   - No panics. Return `Result`.
//!   - Every secret type is `Zeroize` + `ZeroizeOnDrop`.
//!   - Anything serialized uses `BTreeMap`, never `HashMap` — replay must be
//!     byte-identical across devices and platforms.
//!   - `serde_json` output never becomes signed or hashed bytes. Signing
//!     payloads are hand-built, length-prefixed, and domain-separated.
//!
//! # Visibility tiers
//!
//! Three, and there is deliberately no capability tier. `Freeze §5`'s
//! six-function API governs what a **capability** may call; capabilities never
//! link this crate. `airo_mind` is a data-plane subsystem the runtime
//! composes, so its public surface does not contradict `Freeze §5` — and the
//! reason that question kept arising is that nothing said so anywhere.
//!
//!   - **Tier 1, `pub`** — what the runtime host needs. Never names key
//!     material.
//!   - **Tier 2, `pub(crate)`** — what the runtime's own subsystems need.
//!     **Growing this tier is a review decision.** The operation log, sync,
//!     merge, and projections all land inside this boundary in later phases,
//!     written by implementers with less context; `pub(crate)` means every one
//!     of them can reach whatever is in it. This is the tier `LogHead`'s
//!     private field and the restore witness both escaped through.
//!   - **Tier 3, private** — key material, envelope internals, payload
//!     internals.

mod vault;

// The grouping and the comments below ARE the curated surface (`RA-18`): each
// line records the external consumer that justifies the export. rustfmt sorts
// the list alphabetically and re-attaches every comment to whatever ends up
// beneath it, which turns the rationale into noise. Skipped deliberately.
#[rustfmt::skip]
pub use vault::{
    // Onboarding and recovery journey — #1234 / #1235
    generate_mnemonic, seed_from_mnemonic, Seed,     // Seed is opaque: no as_bytes
    RootIdentity, RootPublicKey,
    // `I6` / `A04` / `SEC-47`: the canonical identifiers. A consumer cannot
    // call the Vault without constructing one -- the boundary made unavoidable,
    // for all three RevocationSubject kinds rather than just contexts.
    ContextId, ContentId, DeviceId,
    Vault,
    RecoveryPackage, RECOVERY_PACKAGE_FORMAT_VERSION,
    // Restore path — unreachable in revision 7 without the next two
    SealedRestore, AppliedRestore, RevocationSource, RevocationProvenance,
    // `SEC-48`: `RevocationLedger` and `LogHead` are NOT exported. Revision 9B
    // exported them to make a non-blind restore reachable, which made forging
    // one reachable at the same time. Phase 1 has no log, so it has no honest
    // ReplayedFromLog to reach.
    // `SEC-38`: `trust_device` is `pub` and takes this, so a `pub` API took an
    // unnameable type and the device-trust journey (#1257) was uncallable.
    DeviceCertificate, DeviceKey,
    PurgeDirective, UnlinkOutcome, RevocationSubject,
    // Content path — opaque handles
    ContentEnvelope, ContentKey, SealedEnvelope,
    VaultError,
};

const _: fn() = || {
    fn assert_zeroize_on_drop<T: zeroize::ZeroizeOnDrop>() {}
    assert_zeroize_on_drop::<ed25519_dalek::SigningKey>();
};
