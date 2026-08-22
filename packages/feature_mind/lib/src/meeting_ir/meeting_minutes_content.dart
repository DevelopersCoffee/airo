/// Whether [minutes] is only the empty MoM template — headings plus
/// "No … recorded" lines, no actual extracted content.
///
/// Used so the meeting screen and markdown export can drop that template
/// instead of showing a wall of missing-detail placeholders when extraction
/// found nothing (a short intro, a failed local LLM, …).
bool isEmptyMeetingMinutes(String minutes) {
  var text = minutes;
  const placeholders = [
    'No objective was recorded for this meeting.',
    'No discussion points were recorded for this meeting.',
    '_No decisions recorded._',
    '_No action items recorded._',
    '_No further steps recorded._',
    'No decisions recorded.',
    'No action items recorded.',
    'No metrics recorded.',
  ];
  for (final placeholder in placeholders) {
    text = text.replaceAll(placeholder, '');
  }
  text = text.replaceAll(RegExp(r'^#+\s.*$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\*\*Meeting:\*\*.*'), '');
  text = text.replaceAll('Minutes of Meeting', '');
  return text.replaceAll(RegExp(r'[\s*_#\-]+'), '').isEmpty;
}
