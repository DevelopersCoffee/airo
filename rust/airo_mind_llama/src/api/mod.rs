//! The Flutter-facing surface for generation. `#1401`.
//!
//! `flutter_rust_bridge` generates Dart bindings from **this module only**
//! (`rust_input: crate::api`). Everything below it is invisible to Dart: the
//! bridge exposes a capability, not a runtime.

mod generation_state;

pub mod meeting_intelligence;
pub mod minutes;
