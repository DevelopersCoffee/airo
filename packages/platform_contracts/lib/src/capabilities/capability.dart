enum CapabilityDomain {
  runtime,
  engine,
  model,
  tool,
  storage,
  network,
  system
}

class Capability {
  const Capability({
    required this.domain,
    required this.name,
    this.version = '1.0.0',
  });

  final CapabilityDomain domain;
  final String name;
  final String version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capability &&
          domain == other.domain &&
          name == other.name &&
          version == other.version;

  @override
  int get hashCode => domain.hashCode ^ name.hashCode ^ version.hashCode;

  @override
  String toString() => 'Capability(domain: $domain, name: $name, version: $version)';
}
