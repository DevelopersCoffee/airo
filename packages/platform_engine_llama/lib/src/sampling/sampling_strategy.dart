abstract interface class SamplingStrategy {
  Map<String, dynamic> toConfiguration();
}

class GreedySampling implements SamplingStrategy {
  @override
  Map<String, dynamic> toConfiguration() => {'type': 'greedy'};
}

class TopPSampling implements SamplingStrategy {
  final double p;
  
  const TopPSampling({required this.p});
  
  @override
  Map<String, dynamic> toConfiguration() => {'type': 'top_p', 'p': p};
}
