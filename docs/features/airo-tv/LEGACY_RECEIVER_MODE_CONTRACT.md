# Airo TV Legacy Receiver Mode Contract

This contract defines the v2.0.0.1 platform boundary for Legacy Receiver Mode.
It turns a runtime device profile into an app-consumable mode decision with
navigation, feature, data, visual, delegation, and resource budgets.

Implementation contract:

- Package: `packages/platform_receiver_modes`
- Schema: `kLegacyReceiverModeSchemaVersion`
- Primary policy: `LegacyReceiverModePolicy`
- Input contract: `AiroRuntimeDeviceProfile`
- Output contract: `LegacyReceiverModeContract`

## Ownership Boundary

Legacy Receiver Mode is platform/framework behavior. The Airo TV app may consume
the contract to render a lightweight home, choose navigation entries, hide
unavailable modules, reduce motion, and request companion delegation. It must
not hard-code support tiers, module exclusions, artwork density, or data window
limits in app screens.

The contract composes existing platform contracts:

- `platform_device_profile` for runtime support tier and pressure constraints;
- `product_capabilities` for product profile manifests, modules, navigation,
  capabilities, and resource budgets.

## Mode Outputs

The policy returns a deterministic contract with:

- mode id: off, Lite Receiver, Restricted Lite Receiver, or blocked;
- activation state and stable activation triggers;
- recommended product profile;
- allowed navigation entries and home sections;
- included and disabled product modules;
- data limits for compact EPG, paged catalog, favorites, and recent items;
- visual limits for artwork, animation, previews, and blur-heavy effects;
- companion delegation policy;
- inherited runtime profile constraints.

## Required Use Cases

- Fully supported Full TV devices keep Legacy Receiver Mode off.
- Legacy Optimized devices enable Lite Receiver mode with compact EPG/search,
  D-pad navigation, reduced artwork, reduced motion, and disabled heavy modules.
- Runtime pressure keeps the receiver in Legacy Receiver Mode and exposes a
  pressure trigger for diagnostics.
- Restricted receiver trust enables a restricted Lite Receiver contract.
- Unsupported profiles block mode activation and expose only settings and
  diagnostics-safe fallback navigation.
