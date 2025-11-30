# Template Feature

This is a template package for creating new features in the Airo app.

## How to Use

1. Copy this entire directory to `packages/your_feature_name/`
2. Rename all occurrences of `template` to your feature name
3. Update the `pubspec.yaml` with the correct name and description
4. Implement your domain entities, repositories, and use cases
5. Create your presentation layer (screens, providers, widgets)

## Structure

```
lib/
├── template_feature.dart        # Public API (barrel export)
└── src/
    ├── domain/                  # Domain layer
    │   ├── entities/           # Business entities
    │   └── repositories/       # Repository interfaces
    ├── application/             # Application layer
    │   └── use_cases/          # Use cases
    └── presentation/            # Presentation layer
        ├── screens/            # Screen widgets
        ├── providers/          # Riverpod providers
        └── widgets/            # Feature-specific widgets
test/
└── ...                          # Mirror src/ structure
```

## Dependencies

- `core_domain`: Domain abstractions (Entity, Result, Repository)
- `core_data`: Data layer utilities
- `core_ui`: Shared UI components
- `flutter_riverpod`: State management

