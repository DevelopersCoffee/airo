enum AddonBehaviorKind {
  generative,
  graphWorkflow;

  static AddonBehaviorKind fromJson(String value) {
    switch (value) {
      case 'generative':
        return AddonBehaviorKind.generative;
      case 'graph_workflow':
        return AddonBehaviorKind.graphWorkflow;
      default:
        throw ArgumentError('Unknown add-on behavior: $value');
    }
  }

  String toJson() {
    switch (this) {
      case AddonBehaviorKind.generative:
        return 'generative';
      case AddonBehaviorKind.graphWorkflow:
        return 'graph_workflow';
    }
  }
}
