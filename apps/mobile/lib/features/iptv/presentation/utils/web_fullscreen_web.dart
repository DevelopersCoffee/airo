/// Web implementation for fullscreen functionality
/// This file is used when dart:html is available
library;

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool isFullscreen() {
  return html.document.fullscreenElement != null;
}

void enterFullscreen() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreen() {
  html.document.exitFullscreen();
}

void toggleFullscreen() {
  if (isFullscreen()) {
    exitFullscreen();
  } else {
    enterFullscreen();
  }
}
