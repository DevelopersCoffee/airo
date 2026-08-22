/// One LifeTrack-shaped journey projected from the chat entity graph.
class ProjectedChatJourney {
  const ProjectedChatJourney({
    required this.subjectNodeId,
    required this.templateId,
    required this.title,
    required this.facts,
  });

  final String subjectNodeId;
  final String templateId;
  final String title;
  final Map<String, String> facts;

  bool get isOfferable {
    switch (templateId) {
      case 'insurance_claim_v1':
        return facts.containsKey('Claim ID') ||
            facts.containsKey('Policy Number');
      case 'medical_surgery_v1':
        return facts.containsKey('Hospital') ||
            facts.containsKey('Surgery Date');
      case 'real_estate_under_construction_v1':
        return facts.containsKey('RERA Registration Number') ||
            (_hasBuilder(facts) && facts.containsKey('Project'));
      default:
        return facts.isNotEmpty;
    }
  }

  static bool _hasBuilder(Map<String, String> facts) =>
      facts.containsKey('Builder') ||
      facts.containsKey('Builder Track Record Notes');

  Map<String, dynamic> toPendingWrite() => {
    'title': title,
    'template_id': templateId,
    'facts': facts,
    'confirmed': true,
    'source': 'user_confirm',
  };
}
