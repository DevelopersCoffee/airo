/// HTTP Dog framework - Display HTTP status codes with dog images
/// 
/// This framework provides a fun way to display HTTP status codes throughout
/// the app using dog images from http.dog API.
/// 
/// Usage:
/// ```dart
/// // Display error with dog image
/// HttpDogImage(statusCode: 404)
/// 
/// // Show compact indicator
/// HttpDogIndicator(statusCode: 200)
/// 
/// // Full error screen
/// HttpDogErrorScreen(statusCode: 500, onRetry: () => retry())
/// 
/// // Get status info
/// final status = HttpStatusCodes.fromCode(404);
/// print(status.message); // "Not Found"
/// print(status.dogImageUrl); // "https://http.dog/404.jpg"
/// ```

export 'http_status.dart';
export 'widgets/http_dog_image.dart';
export 'screens/http_status_reference_screen.dart';

