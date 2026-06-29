# Dependency Graph (Program 0 Baseline)

This graph maps the physical dependencies of the Program 0 architecture as enforced by `pubspec.yaml` files.

```mermaid
graph TD
    %% Core Nodes
    platform_core[platform_core]
    platform_logging[platform_logging]
    platform_events[platform_events]
    platform_settings[platform_settings]
    platform_storage[platform_storage]
    platform_filesystem[platform_filesystem]
    design_system[design_system]

    %% Dependencies
    platform_logging --> platform_core
    platform_events --> platform_core
    platform_events --> platform_logging
    platform_settings --> platform_core
    platform_settings --> platform_events
    platform_settings --> platform_logging
    platform_storage --> platform_core
    platform_storage --> platform_logging
    platform_storage --> platform_events
    platform_filesystem --> platform_core
    platform_filesystem --> platform_logging
    platform_filesystem --> platform_events
```

## Constraints
* The graph is strictly acyclic.
* `platform_core` is the root node. It depends on nothing.
* All other packages depend on `platform_core`.
* Storage and Filesystem do not depend on each other.
* Settings depends on Events to broadcast changes, but Events does not depend on Settings.
