enum DetectionConfidence {
  exact,
  derived,
  estimated,
  unknown,
}

class DetectionResult<T> {

  const DetectionResult({
    required this.value,
    required this.confidence,
  });
  final T value;
  final DetectionConfidence confidence;
}
