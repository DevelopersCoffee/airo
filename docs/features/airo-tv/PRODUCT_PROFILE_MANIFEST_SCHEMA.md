# Product Profile Manifest Schema

Issue: ATV-059
Package: `product_capabilities`
Layer: Platform framework, consumed by Airo TV app and release code

## Purpose

Product profile manifests define which modules, capabilities, navigation
entries, permissions, resource budgets, guarantees, release channel, and support
level a product surface may expose. Airo TV app code consumes these manifests to
hide unavailable sections and avoid profile-specific shortcuts in screens.

This contract belongs in `product_capabilities` because profile composition is a
reusable platform boundary shared by Full TV, Lite Receiver, Embedded Receiver,
legacy experimental builds, release validation, and QA automation.

## Manifest Fields

`ProductProfileManifest` includes:

- `profileId`: stable product profile id.
- `displayName`: user-facing profile name.
- `supportLevel`: certified, compatible, experimental, or unsupported.
- `releaseChannel`: stable channel such as Full TV stable, Lite Receiver
  stable, legacy experimental, vendor-specific, or internal certification.
- `includedModules`: modules compiled or enabled for the profile.
- `excludedModules`: modules explicitly unavailable for the profile.
- `capabilities`: runtime capabilities that product code may advertise.
- `navigation`: navigation entries the UI may render.
- `androidPermissions`: permissions the profile is allowed to request.
- `guarantees`: stable product guarantees such as BYOC-only behavior,
  permission minimization, restricted-trust compatibility, and profile-scoped
  navigation.
- `resourceBudget`: memory, storage, artwork cache, and background-job budgets.
- `deviceRequirement`: runtime device capability requirements.

Public manifest maps expose stable ids and numeric budgets only. They must not
contain local paths, provider payloads, store-console account values, private
release material, raw credentials, or device logs.

## Validation Rules

`ProductProfileManifestPolicy` returns stable validation codes for:

- overlapping included and excluded modules;
- navigation entries without backing modules or capabilities;
- declared capabilities without backing modules;
- unsupported Android permissions;
- invalid resource budgets;
- release-channel/profile mismatches;
- support-level/release-channel mismatches.

## Airo TV Defaults

`AiroTvProductProfiles.fullTv()` uses `full_tv_stable`, certified support,
Full TV navigation, Full EPG capability, diagnostics, analytics, and stable
Full TV guarantees.

`AiroTvProductProfiles.liteReceiver()` uses `lite_receiver_stable`,
compatible support, compact navigation, compact EPG, diagnostics, companion
remote, restricted-trust compatibility, and no heavy modules such as local AI,
recording, downloads, multiview, or Full EPG.

## Automation

- Unit tests assert default Full TV and Lite Receiver manifests validate.
- Unit tests reject module overlap, unsupported navigation, unsupported
  capability declarations, unsupported permissions, invalid budgets, and
  release-channel/support-level mismatches.
- Public-map tests verify redacted, stable manifest output.
