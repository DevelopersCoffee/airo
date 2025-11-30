# ADR-0001: Modular Package Structure

## Status

Accepted

## Date

2025-11-30

## Context

Airo is a multi-feature super app with AI integration, finance tracking, games, and more. The codebase needs:
- Clear separation of concerns
- Independent testability
- Shared code reuse across features
- Prevention of circular dependencies
- Support for multi-platform (Android, iOS, Web)

Currently, all code resides in `app/lib/core/` and `app/lib/features/` without clear package boundaries.

## Decision

We adopt a modular monorepo structure using Melos with the following core packages:

```
packages/
├── core_domain/     # Domain entities, repository interfaces, use cases
├── core_data/       # Data layer: DB, API clients, repositories
├── core_ui/         # Shared widgets, theme, design tokens
├── core_ai/         # AI abstractions: LLM clients, prompt management
├── core_auth/       # Authentication: login, session, secure storage
├── airo/            # Super-app shell package
├── airomoney/       # Finance feature package
└── template_feature/# Feature template for new features
```

### Dependency Rules

1. **core_domain** has no dependencies on other packages
2. **core_data** depends only on core_domain
3. **core_ui** has no business logic dependencies
4. **core_ai** depends on core_domain
5. **core_auth** depends on core_domain, core_data
6. Feature packages depend on core_* packages

### Layer Structure (per package)

```
lib/
├── src/
│   ├── domain/       # Entities, value objects, repo interfaces
│   ├── data/         # Implementations, data sources
│   ├── application/  # Use cases, services
│   └── presentation/ # Widgets, screens, view models
├── package_name.dart # Public barrel export
test/
└── ...
```

## Consequences

### Positive

- Clear ownership and boundaries
- Independent testing per package
- Faster incremental builds
- Prevents spaghetti dependencies
- Enables feature teams to work independently

### Negative

- Initial refactoring effort required
- More files and boilerplate
- Learning curve for new developers

### Risks

- Over-engineering if packages become too granular
- Potential version conflicts between packages

## Alternatives Considered

### Alternative 1: Monolithic app structure

Keep all code in `app/lib/`. Rejected due to growing complexity and lack of boundaries.

### Alternative 2: Separate git repositories

Each package as a separate repo. Rejected due to coordination overhead and versioning complexity.

## References

- [Melos Documentation](https://melos.invertase.dev/)
- [Flutter Package Structure Best Practices](https://docs.flutter.dev/packages-and-plugins/developing-packages)

