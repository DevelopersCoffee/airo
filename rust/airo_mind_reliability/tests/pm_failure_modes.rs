//! PM-01..PM-16 fixture suite: reproduce, classify, identify invariant,
//! select recovery, revalidate, and refuse invalid completion.

use airo_mind_reliability::{
    apply_recovery_to_goal, verify_completion, CheckpointMetadata, CheckpointStatus,
    CompletionCriterion, CompletionVerification, ExecutionCheckpoint, ExecutionId, ExecutionLog,
    ExecutionStage, FailureClassifier, FailureMode, GoalState, GoalStatus, InvariantId,
    PipelineObservation, RecoveryAction, RecoveryDecision, RecoveryEngine, RecoveryPolicy,
};

struct Fixture {
    mode: FailureMode,
    observation: PipelineObservation,
    invariant: InvariantId,
    repair: RecoveryAction,
}

fn fixtures() -> Vec<Fixture> {
    vec![
        Fixture {
            mode: FailureMode::Pm01HallucinationChunkDrift,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.grounding_failed = true;
                o
            },
            invariant: InvariantId::ModelResultGrounded,
            repair: RecoveryAction::ReRetrieve,
        },
        Fixture {
            mode: FailureMode::Pm02InterpretationCollapse,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.intent_confidence = Some(0.41);
                o
            },
            invariant: InvariantId::GoalStateConsistent,
            repair: RecoveryAction::ReinterpretIntent,
        },
        Fixture {
            mode: FailureMode::Pm03LongChainDrift,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.goal_step_drift = true;
                o
            },
            invariant: InvariantId::GoalStateConsistent,
            repair: RecoveryAction::Replan,
        },
        Fixture {
            mode: FailureMode::Pm04ConfidentNonsense,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.answer_fluent = true;
                o.evidence_present = false;
                o
            },
            invariant: InvariantId::ModelResultGrounded,
            repair: RecoveryAction::ValidateWithTool,
        },
        Fixture {
            mode: FailureMode::Pm05SemanticEmbeddingMismatch,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.retrieval_score = Some(0.92);
                o.semantic_score = Some(0.31);
                o
            },
            invariant: InvariantId::RetrievalSemanticAlignment,
            repair: RecoveryAction::Rerank,
        },
        Fixture {
            mode: FailureMode::Pm06LogicCollapse,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.state_skipped_replan = true;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Replan,
        },
        Fixture {
            mode: FailureMode::Pm07MemoryFailure,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.memory_conflict = true;
                o
            },
            invariant: InvariantId::MemoryConsistency,
            repair: RecoveryAction::RebuildContext,
        },
        Fixture {
            mode: FailureMode::Pm08BlackBox,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.checkpoints_recorded = false;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Abort,
        },
        Fixture {
            mode: FailureMode::Pm09ContextCollapse,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.context_token_pressure = true;
                o
            },
            invariant: InvariantId::ContextWithinBudget,
            repair: RecoveryAction::RebuildContext,
        },
        Fixture {
            mode: FailureMode::Pm10CreativeFreeze,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.answer_fluent = true;
                o.evidence_present = true;
                o.creative_diversity = Some(0.05);
                o
            },
            invariant: InvariantId::GoalStateConsistent,
            repair: RecoveryAction::Retry,
        },
        Fixture {
            mode: FailureMode::Pm11SymbolicCollapse,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.schema_valid = false;
                o.symbolic_task = true;
                o
            },
            invariant: InvariantId::OutputSchemaValid,
            repair: RecoveryAction::Retry,
        },
        Fixture {
            mode: FailureMode::Pm12PhilosophicalRecursion,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.recursion_depth = 8;
                o.recursion_limit = 8;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Abort,
        },
        Fixture {
            mode: FailureMode::Pm13MultiAgentChaos,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.shared_state_write_conflict = true;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Abort,
        },
        Fixture {
            mode: FailureMode::Pm14BootstrapOrdering,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.bootstrap_order_invalid = true;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Abort,
        },
        Fixture {
            mode: FailureMode::Pm15DeploymentDeadlock,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.circular_dependency = true;
                o
            },
            invariant: InvariantId::StateTransitionValid,
            repair: RecoveryAction::Abort,
        },
        Fixture {
            mode: FailureMode::Pm16PreDeployCollapse,
            observation: {
                let mut o = PipelineObservation::healthy();
                o.adversarial_eval_failed = true;
                o
            },
            invariant: InvariantId::CompletionVerified,
            repair: RecoveryAction::Abort,
        },
    ]
}

fn run_loop(fixture: &Fixture) {
    let execution_id = ExecutionId::new(format!("exec_{}", fixture.mode.id()));
    let mut log = ExecutionLog::new();
    log.record(ExecutionCheckpoint {
        execution_id: execution_id.clone(),
        stage: ExecutionStage::Validation,
        status: CheckpointStatus::Failed,
        timestamp_ms: 1,
        metadata: CheckpointMetadata {
            failure_mode: Some(fixture.mode),
            invariant: Some(fixture.invariant),
            ..CheckpointMetadata::default()
        },
    });

    let classification = FailureClassifier::classify(&fixture.observation)
        .unwrap_or_else(|| panic!("{} was not detected", fixture.mode.id()));
    assert_eq!(
        classification.primary,
        fixture.mode,
        "{}",
        fixture.mode.id()
    );
    assert_eq!(classification.invariant, fixture.invariant);
    assert_eq!(classification.first_repair, fixture.repair);

    let mut engine = RecoveryEngine::new(RecoveryPolicy::default());
    let decision = engine.select(&classification);
    let mut goal = GoalState::new(fixture.mode.id());
    goal.transition(GoalStatus::Planning).unwrap();
    goal.transition(GoalStatus::Executing).unwrap();

    match decision {
        RecoveryDecision::Abort => {
            assert_eq!(fixture.repair, RecoveryAction::Abort);
            goal.transition(GoalStatus::Failed).unwrap();
            assert_ne!(goal.status, GoalStatus::Completed);
            assert_eq!(
                verify_completion(&[CompletionCriterion {
                    id: "verified".into(),
                    satisfied: false,
                }]),
                CompletionVerification::Failed
            );
        }
        RecoveryDecision::Execute(action) => {
            engine.note_attempt(action);
            assert_eq!(action, fixture.repair);
            // Recovery executed, then revalidated as still failing: cannot complete.
            goal.transition(GoalStatus::Failed).unwrap();
            assert!(goal.transition(GoalStatus::Completed).is_err());
            let status =
                apply_recovery_to_goal(&mut goal, action, CompletionVerification::Failed).unwrap();
            assert_ne!(status, GoalStatus::Completed);
        }
    }

    assert!(
        log.last_failure().is_some(),
        "{} left no failure checkpoint",
        fixture.mode.id()
    );
}

#[test]
fn every_pm_mode_has_a_fixture() {
    let modes: Vec<_> = fixtures().into_iter().map(|f| f.mode).collect();
    assert_eq!(modes, FailureMode::ALL.to_vec());
}

#[test]
fn pm01_through_pm16_detect_classify_recover_and_refuse_false_completion() {
    for fixture in fixtures() {
        run_loop(&fixture);
    }
}

#[test]
fn tool_claim_without_execution_is_airo_r03() {
    let mut o = PipelineObservation::healthy();
    o.tool_claimed = true;
    o.tool_executed = false;
    o.answer_fluent = true;
    let c = FailureClassifier::classify(&o).unwrap();
    assert_eq!(c.primary, FailureMode::Pm04ConfidentNonsense);
    assert_eq!(
        c.runtime_error,
        Some(airo_mind_reliability::RuntimeFailure::R03ToolAuthorization)
    );
    assert_eq!(c.invariant, InvariantId::ToolExecutionAuthority);
    assert_eq!(c.first_repair, RecoveryAction::Abort);
}

#[test]
fn recovered_grounding_may_complete_only_after_verification() {
    let mut goal = GoalState::new("find meeting");
    goal.transition(GoalStatus::Planning).unwrap();
    goal.transition(GoalStatus::Executing).unwrap();
    let status = apply_recovery_to_goal(
        &mut goal,
        RecoveryAction::ReRetrieve,
        CompletionVerification::Passed,
    )
    .unwrap();
    assert_eq!(status, GoalStatus::Completed);
}
