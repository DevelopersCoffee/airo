import '../../whisper/api/meetings.dart' as rust;
import '../domain/processing_profile.dart';

extension ProcessingProfileBridge on ProcessingProfile {
  rust.FinalProcessingProfile get rustProfile => switch (this) {
    ProcessingProfile.fast => rust.FinalProcessingProfile.fast,
    ProcessingProfile.balanced => rust.FinalProcessingProfile.balanced,
    ProcessingProfile.maximumQuality =>
      rust.FinalProcessingProfile.maximumQuality,
  };
}
