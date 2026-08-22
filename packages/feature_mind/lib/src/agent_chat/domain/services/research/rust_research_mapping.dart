import '../../models/research_event.dart';
import '../../models/research_request.dart';
import '../../../../llama/api/research.dart' as frb;
import 'research_checkpoint.dart';

ResearchEvent mapFrbResearchEvent(frb.FrbResearchEvent event) {
  return ResearchEvent(
    kind: mapFrbResearchEventKind(event.kind),
    jobId: event.jobId,
    label: event.label,
    detail: event.detail,
  );
}

ResearchEventKind mapFrbResearchEventKind(frb.FrbResearchEventKind kind) {
  switch (kind) {
    case frb.FrbResearchEventKind.jobAdmitted:
      return ResearchEventKind.jobAdmitted;
    case frb.FrbResearchEventKind.planningStarted:
      return ResearchEventKind.planningStarted;
    case frb.FrbResearchEventKind.intentClassified:
      return ResearchEventKind.intentClassified;
    case frb.FrbResearchEventKind.planCreated:
      return ResearchEventKind.planCreated;
    case frb.FrbResearchEventKind.searchStarted:
      return ResearchEventKind.searchStarted;
    case frb.FrbResearchEventKind.searchCompleted:
      return ResearchEventKind.searchCompleted;
    case frb.FrbResearchEventKind.sourceDiscovered:
      return ResearchEventKind.sourceDiscovered;
    case frb.FrbResearchEventKind.sourceFetched:
      return ResearchEventKind.sourceFetched;
    case frb.FrbResearchEventKind.sourceRejected:
      return ResearchEventKind.sourceRejected;
    case frb.FrbResearchEventKind.documentParsed:
      return ResearchEventKind.documentParsed;
    case frb.FrbResearchEventKind.analyzingStarted:
      return ResearchEventKind.analyzingStarted;
    case frb.FrbResearchEventKind.claimCreated:
      return ResearchEventKind.claimCreated;
    case frb.FrbResearchEventKind.gapDetected:
      return ResearchEventKind.gapDetected;
    case frb.FrbResearchEventKind.counterResearchStarted:
      return ResearchEventKind.counterResearchStarted;
    case frb.FrbResearchEventKind.conflictDetected:
      return ResearchEventKind.conflictDetected;
    case frb.FrbResearchEventKind.synthesisStarted:
      return ResearchEventKind.synthesisStarted;
    case frb.FrbResearchEventKind.completed:
      return ResearchEventKind.researchCompleted;
    case frb.FrbResearchEventKind.failed:
      return ResearchEventKind.researchFailed;
    case frb.FrbResearchEventKind.paused:
      return ResearchEventKind.researchPaused;
    case frb.FrbResearchEventKind.cancelled:
      return ResearchEventKind.researchCancelled;
  }
}

frb.FrbResearchCheckpoint mapResearchCheckpoint(ResearchCheckpoint checkpoint) {
  return frb.FrbResearchCheckpoint(record: checkpoint.toRecord());
}

frb.FrbResearchRequest mapResearchRequest(ResearchRequest request) {
  return frb.FrbResearchRequest(
    question: request.question,
    mode: mapResearchMode(request.mode),
    policy: mapSearchPolicy(request.policy),
    outputFormat: request.outputFormat,
  );
}

frb.FrbResearchMode mapResearchMode(ResearchMode mode) {
  switch (mode) {
    case ResearchMode.quick:
      return frb.FrbResearchMode.quick;
    case ResearchMode.standard:
      return frb.FrbResearchMode.standard;
    case ResearchMode.deep:
      return frb.FrbResearchMode.deep;
    case ResearchMode.exhaustive:
      return frb.FrbResearchMode.exhaustive;
  }
}

frb.FrbSearchPolicy mapSearchPolicy(SearchPolicy policy) {
  switch (policy) {
    case SearchPolicy.localOnly:
      return frb.FrbSearchPolicy.localOnly;
    case SearchPolicy.privacyFirst:
      return frb.FrbSearchPolicy.privacyFirst;
    case SearchPolicy.balanced:
      return frb.FrbSearchPolicy.balanced;
    case SearchPolicy.maximumQuality:
      return frb.FrbSearchPolicy.maximumQuality;
    case SearchPolicy.academic:
      return frb.FrbSearchPolicy.academic;
  }
}
