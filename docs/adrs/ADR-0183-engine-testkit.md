# ADR-0183: Platform Engine Test Kit

## Status
Accepted

## Context
If multiple inference engines (llama.cpp, LiteRT, CoreML, etc.) are built independently based purely on the `platform_engine_sdk` interfaces, their behaviors will diverge. For example, some engines might throw an exception when cancelling a stream, while others silently swallow it. This creates unpredictable bugs at the orchestrator level.

## Decision
We mandate a dedicated `platform_engine_testkit` package that serves as an executable specification.

### Key Patterns
1. **Separation of Contract and Verification**: The SDK defines the API shapes, but the Test Kit enforces semantic behavior.
2. **EngineFixture**: Engines provide an `EngineFixture` containing a mock/configured instance of their provider and an `InstalledArtifact`. The Test Kit consumes this fixture to run identical assertions against all engines.
3. **Mandatory Compliance**: No inference engine can be registered in `platform_runtime` unless its test suite successfully executes `EngineComplianceSuite.run(MyEngineFixture())`.

## Consequences
- **Positive**: We guarantee absolute behavioral consistency across platforms and engines. New engines can be added rapidly with confidence.
- **Negative**: Adds a layer of indirection to test writing. Engine developers must implement the fixture interface to run their tests.
