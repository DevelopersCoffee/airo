/// Stub implementation of flutter_tts for TV builds
library;

/// Stub FlutterTts
class FlutterTts {
  /// Speak text
  Future<dynamic> speak(String text) async => 1;
  
  /// Stop speaking
  Future<dynamic> stop() async => 1;
  
  /// Pause speaking
  Future<dynamic> pause() async => 1;
  
  /// Set language
  Future<dynamic> setLanguage(String language) async => 1;
  
  /// Set speech rate
  Future<dynamic> setSpeechRate(double rate) async => 1;
  
  /// Set volume
  Future<dynamic> setVolume(double volume) async => 1;
  
  /// Set pitch
  Future<dynamic> setPitch(double pitch) async => 1;
  
  /// Get languages
  Future<dynamic> getLanguages() async => <String>[];
  
  /// Get engines
  Future<dynamic> getEngines() async => <String>[];
  
  /// Set engine
  Future<dynamic> setEngine(String engine) async => 1;
  
  /// Await speak completion
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;
  
  /// Check if language is available
  Future<dynamic> isLanguageAvailable(String language) async => false;
  
  /// Set completion handler
  void setCompletionHandler(Function handler) {}
  
  /// Set error handler
  void setErrorHandler(Function handler) {}
  
  /// Set start handler
  void setStartHandler(Function handler) {}
  
  /// Set progress handler
  void setProgressHandler(Function handler) {}
}

