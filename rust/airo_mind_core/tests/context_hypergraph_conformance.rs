//! Context hypergraph conformance — `#1229`, `#1197`'s epic.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/destroy_content_conformance.rs` and
//! `tests/operation_log_and_projection_conformance.rs`.
//!
//! `#1229`'s scope, verbatim: *"`LinkContent`/`UnlinkContent` end to end...
//! survival computation: for any destructive action, the runtime computes
//! exactly what survives elsewhere and what exists nowhere else... context
//! restructuring... moves no content and rewrites no history. Only links
//! change."*
//!
//! This suite proves four things end to end, through
//! [`airo_mind_core::CapabilityApi`] alone (never `Runtime` directly, except
//! where a test needs to prove something about the underlying content store
//! that the capability surface intentionally does not expose):
//!
//! 1. One content object can belong to many contexts at once (the "hyper"
//!    part).
//! 2. Unlinking from one context never destroys content that survives in
//!    another.
//! 3. Destroying an entity's last context reference is reported correctly by
//!    the survival computation, and is a different, more severe action than
//!    an ordinary unlink.
//! 4. All of the above rebuilds correctly from the operation log alone —
//!    condition 5's delete-and-rebuild pattern, applied to the hypergraph.

use airo_mind_core::{
    CapabilityApi, ContentId, ContextHypergraphProjection, CreateOperationRequest, ResourceBudget,
    Runtime, Verb,
};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "airo_mind_context_hypergraph_conformance_{name}_{unique}.log"
    ))
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

/// A minimal fake capability built entirely on [`CapabilityApi`] — the same
/// "holds nothing but the handle" discipline `NotesCapability` and
/// `capability_api`'s own `FakeContactCapability` follow.
struct FakeFinanceCapability<'a> {
    api: CapabilityApi<'a>,
}

impl<'a> FakeFinanceCapability<'a> {
    fn new(runtime: &'a Runtime) -> Self {
        Self {
            api: CapabilityApi::new(runtime, "fake_finance"),
        }
    }

    fn create_context(&self, id: &str, label: &str, recorded_at_ms: u64) {
        self.api
            .create_context(id, label.as_bytes(), recorded_at_ms)
            .unwrap();
    }

    fn create_content_in(
        &self,
        entity_id: &str,
        context_id: &str,
        bytes: &[u8],
        recorded_at_ms: u64,
    ) -> ContentId {
        let context_ids = [context_id];
        let mut req = CreateOperationRequest::verb(Verb::CreateContent, recorded_at_ms);
        req.entity_id = entity_id;
        req.context_ids = &context_ids;
        req.content = Some(bytes);
        self.api.create_operation(req).unwrap().content_id.unwrap()
    }

    fn link(
        &self,
        content_id: ContentId,
        entity_id: &str,
        context_ids: &[&str],
        recorded_at_ms: u64,
    ) {
        self.api
            .link_content(content_id, entity_id, context_ids, recorded_at_ms)
            .unwrap();
    }

    fn unlink(
        &self,
        content_id: ContentId,
        entity_id: &str,
        context_ids: &[&str],
        recorded_at_ms: u64,
    ) {
        self.api
            .unlink_content(content_id, entity_id, context_ids, recorded_at_ms)
            .unwrap();
    }

    fn hypergraph(&self) -> ContextHypergraphProjection {
        self.api
            .query_projection::<ContextHypergraphProjection>()
            .unwrap()
    }
}

/// Condition 1: an entity — here, one content object — belongs to multiple
/// contexts simultaneously. Design doc §4.1's hospital-bill example: a
/// medical record, an expense, and a tax deduction, all one object.
#[test]
fn a_content_object_belongs_to_multiple_contexts_simultaneously_through_the_capability_api() {
    let path = temp_log_path("multi_context");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let finance = FakeFinanceCapability::new(&runtime);

    finance.create_context("hospitalization", "Hospitalization", 1);
    finance.create_context("finance", "Finance", 2);
    finance.create_context("insurance-claim", "Insurance Claim", 3);
    finance.create_context("tax-2026", "Tax Year 2026", 4);
    finance.create_context("expense", "Expense", 5);

    let bill = finance.create_content_in("bill-1", "hospitalization", b"hospital bill", 6);
    finance.link(
        bill.clone(),
        "bill-1",
        &["finance", "insurance-claim", "tax-2026", "expense"],
        7,
    );

    let graph = finance.hypergraph();
    let mut contexts = graph.contexts_for_content(&bill);
    contexts.sort_unstable();
    assert_eq!(
        contexts,
        vec![
            "expense",
            "finance",
            "hospitalization",
            "insurance-claim",
            "tax-2026"
        ]
    );
    assert!(graph.content_survives(&bill));

    cleanup(&path);
}

/// Condition 2: unlinking from one context does not destroy the entity if it
/// survives in another. Proven both through the projection's own report and
/// by reading the raw bytes back — the content is genuinely untouched, not
/// merely reported as untouched.
#[test]
fn unlinking_from_one_context_leaves_content_readable_and_alive_in_the_others() {
    let path = temp_log_path("unlink_survives");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let finance = FakeFinanceCapability::new(&runtime);

    finance.create_context("hospitalization", "Hospitalization", 1);
    finance.create_context("finance", "Finance", 2);
    finance.create_context("tax-2026", "Tax Year 2026", 3);

    let bill = finance.create_content_in("bill-1", "hospitalization", b"hospital bill", 4);
    finance.link(bill.clone(), "bill-1", &["finance", "tax-2026"], 5);

    // Closing the hospitalization: unlink from that one context only.
    finance.unlink(bill.clone(), "bill-1", &["hospitalization"], 6);

    let graph = finance.hypergraph();
    let mut remaining = graph.contexts_for_content(&bill);
    remaining.sort_unstable();
    assert_eq!(remaining, vec!["finance", "tax-2026"]);
    assert!(
        graph.content_survives(&bill),
        "content linked into Finance and Tax 2026 must survive the hospitalization unlink"
    );
    assert!(!graph.is_content_destroyed(&bill));

    // The bytes themselves are provably intact -- `UnlinkContent` never
    // touches the content store, unlike `DestroyContent`.
    assert_eq!(
        runtime.read_content(&bill).unwrap().unwrap(),
        b"hospital bill"
    );

    cleanup(&path);
}

/// Condition 3: destroying an entity's last context reference. The survival
/// computation run *before* the destructive unlink correctly predicts "this
/// is effectively a destroy" — `exists_nowhere_else: true` — even though the
/// verb being considered is `Unlink`, not `Destroy`. This is exactly the
/// distinction design §4.1 says a confirmation dialog must be able to draw.
#[test]
fn unlinking_the_last_context_reference_is_predicted_and_confirmed_as_exists_nowhere_else() {
    let path = temp_log_path("last_reference");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let finance = FakeFinanceCapability::new(&runtime);

    finance.create_context("hospitalization", "Hospitalization", 1);
    let receipt = finance.create_content_in("receipt-1", "hospitalization", b"a lone receipt", 2);

    // Preview: what would survive if this, the only context, were unlinked?
    let preview = finance.hypergraph();
    let report = preview.survival_if_unlinked(&receipt, &["hospitalization"]);
    assert!(report.exists_nowhere_else);
    assert!(report.surviving_contexts.is_empty());

    // The preview must not have mutated anything -- the receipt is still
    // linked and readable.
    assert_eq!(
        preview.contexts_for_content(&receipt),
        vec!["hospitalization"]
    );
    assert_eq!(
        runtime.read_content(&receipt).unwrap().unwrap(),
        b"a lone receipt"
    );

    // Now actually take the action the preview predicted.
    finance.unlink(receipt.clone(), "receipt-1", &["hospitalization"], 3);

    let after = finance.hypergraph();
    assert!(after.contexts_for_content(&receipt).is_empty());
    assert!(
        !after.content_survives(&receipt),
        "content with zero remaining context links has no wrapping left, per design §4.1"
    );
    // Critically: `Unlink`, even of the last reference, is not `Destroy`.
    // The bytes are still physically present -- crypto-shredding never
    // happened, because no `DestroyContent` was ever emitted.
    assert!(!after.is_content_destroyed(&receipt));
    assert_eq!(
        runtime.read_content(&receipt).unwrap().unwrap(),
        b"a lone receipt",
        "Unlink must never physically destroy bytes -- only DestroyContent may"
    );

    cleanup(&path);
}

/// The other destructive verb: `DestroyContent`'s own survival report is
/// always `exists_nowhere_else: true` by construction, and is genuinely
/// irreversible -- distinct from the last-unlink case above, where the bytes
/// remain recoverable by linking a fresh context back in.
#[test]
fn destroy_content_survival_is_always_exists_nowhere_else_and_is_irreversible() {
    let path = temp_log_path("destroy_survival");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let finance = FakeFinanceCapability::new(&runtime);

    finance.create_context("hospitalization", "Hospitalization", 1);
    finance.create_context("finance", "Finance", 2);
    let bill = finance.create_content_in("bill-1", "hospitalization", b"bill bytes", 3);
    finance.link(bill.clone(), "bill-1", &["finance"], 4);

    let before = finance.hypergraph();
    let report = before.survival_if_destroyed(&bill);
    assert!(report.exists_nowhere_else);
    assert!(report.surviving_contexts.is_empty());
    // Unlike the unlink preview, this reports the answer for the whole
    // wrapping set at once, regardless of how many contexts currently link
    // it -- `Destroy` removes every wrapping, not one.
    let mut still_linked_before_destroy = before.contexts_for_content(&bill);
    still_linked_before_destroy.sort_unstable();
    assert_eq!(
        still_linked_before_destroy,
        vec!["finance", "hospitalization"]
    );

    finance
        .api
        .destroy_content(bill.clone(), "bill-1", 5)
        .unwrap();

    let after = finance.hypergraph();
    assert!(after.is_content_destroyed(&bill));
    assert!(after.contexts_for_content(&bill).is_empty());
    assert!(runtime.read_content(&bill).unwrap().is_none());

    // Irreversibility: relinking a destroyed content id into a fresh context
    // does not resurrect it in the hypergraph -- unlike the last-unlink
    // case, there is no path back.
    finance.link(bill.clone(), "bill-1", &["finance"], 6);
    let still_after_relink = finance.hypergraph();
    assert!(still_after_relink.is_content_destroyed(&bill));
    assert!(still_after_relink.contexts_for_content(&bill).is_empty());

    cleanup(&path);
}

/// Condition 4: all of the above rebuilds correctly from the operation log
/// alone. Delete every in-memory projection, replay, and fold fresh --
/// condition 5's pattern (`operation_log_and_projection_conformance.rs`,
/// `destroy_content_conformance.rs`), applied here to the hypergraph plus
/// the context-restructuring graph in the same log.
#[test]
fn the_full_hypergraph_state_rebuilds_identically_from_the_operation_log_alone() {
    use airo_mind_core::rebuild_from_scratch;

    let path = temp_log_path("full_rebuild");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let finance = FakeFinanceCapability::new(&runtime);

    finance.create_context("hospitalization", "Hospitalization", 1);
    finance.create_context("finance", "Finance", 2);
    finance.create_context("tax-2026", "Tax Year 2026", 3);

    let bill = finance.create_content_in("bill-1", "hospitalization", b"bill bytes", 4);
    finance.link(bill.clone(), "bill-1", &["finance", "tax-2026"], 5);
    finance.unlink(bill.clone(), "bill-1", &["hospitalization"], 6);

    let receipt = finance.create_content_in("receipt-1", "finance", b"a receipt", 7);
    finance
        .api
        .destroy_content(receipt.clone(), "receipt-1", 8)
        .unwrap();

    // Context restructuring: merge Tax 2026 into Finance -- only a link,
    // no content moves.
    finance
        .api
        .link_context("tax-2026", &["finance"], 9)
        .unwrap();

    let before = finance.hypergraph();
    let mut before_bill_contexts: Vec<String> = before
        .contexts_for_content(&bill)
        .into_iter()
        .map(String::from)
        .collect();
    before_bill_contexts.sort_unstable();
    let before_receipt_destroyed = before.is_content_destroyed(&receipt);
    let mut before_linked: Vec<String> = before
        .linked_contexts("tax-2026")
        .into_iter()
        .map(String::from)
        .collect();
    before_linked.sort_unstable();
    drop(before);

    // "Delete": nothing else retains this state -- `ContextHypergraphProjection`
    // holds no cache of its own (`I2`/`I4`), same as every other projection
    // in this crate.
    let ops = runtime.replay().unwrap();
    let after: ContextHypergraphProjection = rebuild_from_scratch(&ops);

    let mut after_bill_contexts: Vec<String> = after
        .contexts_for_content(&bill)
        .into_iter()
        .map(String::from)
        .collect();
    after_bill_contexts.sort_unstable();
    assert_eq!(before_bill_contexts, after_bill_contexts);
    assert_eq!(after_bill_contexts, vec!["finance", "tax-2026"]);

    assert_eq!(
        before_receipt_destroyed,
        after.is_content_destroyed(&receipt)
    );
    assert!(after.is_content_destroyed(&receipt));

    let mut after_linked: Vec<String> = after
        .linked_contexts("tax-2026")
        .into_iter()
        .map(String::from)
        .collect();
    after_linked.sort_unstable();
    assert_eq!(before_linked, after_linked);
    assert_eq!(after_linked, vec!["finance"]);

    // Labels survive the rebuild too -- context nodes are user data, not
    // regenerated.
    assert_eq!(
        after.context("hospitalization").unwrap().label,
        "Hospitalization"
    );
    assert_eq!(after.context("finance").unwrap().label, "Finance");

    // And through the ordinary query path too, not just a direct
    // `rebuild_from_scratch` call -- the same double-proof pattern
    // `projection.rs`'s own `two_projections_survive_delete_and_rebuild...`
    // test uses.
    let via_query = finance.hypergraph();
    assert_eq!(via_query, after);

    cleanup(&path);
}
