/// Stub implementation for non-web platforms
/// This file is used when dart:html is not available

bool isFullscreen() => false;

void enterFullscreen() {
  // No-op on non-web platforms
}

void exitFullscreen() {
  // No-op on non-web platforms
}

void toggleFullscreen() {
  // No-op on non-web platforms
}
