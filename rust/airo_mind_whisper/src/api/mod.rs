//! The Flutter-facing surface. `#1401`.
//!
//! `flutter_rust_bridge` generates Dart bindings from **this module only**
//! (`rust_input: crate::api`). Everything below it is invisible to Dart, which
//! is the point: the bridge exposes a capability, not a runtime.
//!
//! `wav` and `models` deliberately sit outside this module, in
//! `airo_mind_core`. Anything under `api` is generated into Dart, and `Pcm` is
//! how the capability hands audio to the engine -- not something Dart ever
//! sees. (`#[frb(ignore)]` cannot express this: an attribute on a file module
//! is unstable in Rust.)

pub mod meetings;
pub mod mind_runtime;
pub mod setup;
