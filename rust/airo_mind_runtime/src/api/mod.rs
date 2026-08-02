//! The Flutter-facing surface. `#1401`.
//!
//! `flutter_rust_bridge` generates Dart bindings from **this module only**
//! (`rust_input: crate::api`). Everything below it is invisible to Dart, which
//! is the point: the bridge exposes a capability, not a runtime.
//!
//! Gated on both backends. A bridge that compiles without the models would
//! generate a Dart API whose every call fails at run time.

//! `wav` and `models` deliberately sit OUTSIDE this module, at `crate::wav`. Anything under
//! `api` is generated into Dart, and `Pcm` is how the capability hands audio to
//! the engine -- not something Dart ever sees. (`#[frb(ignore)]` cannot express
//! this: an attribute on a file module is unstable in Rust.)

pub mod mind;
pub mod setup;
