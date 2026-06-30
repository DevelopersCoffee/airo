abstract interface class SamplingStrategy {
  Map<String, dynamic> toConfiguration();
}

class GreedySampling implements SamplingStrategy {
  @override
  Map<String, dynamic> toConfiguration() => {'type': 'greedy'};
}

class TopPSampling implements SamplingStrategy {
  
  const TopPSampling({required this.p});
  final double p;
  
  @override
  Map<String, dynamic> toConfiguration() => {'type': 'top_p', 'p': p};
}
