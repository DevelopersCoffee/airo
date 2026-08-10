/// Columns the console can sort by.
///
/// `sequence` is the port's native order (`OperationLogPort.range` always
/// returns newest-sequence-first), so sorting by it never needs a re-fetch —
/// only the comparator's sign flips. The other columns reorder whatever page
/// of rows is already loaded; they do not imply "load the rest of the log to
/// sort it globally," which is the one thing this table must never do.
enum RuntimeConsoleSortField { sequence, time, kind, title, device }

enum RuntimeConsoleSortDirection { ascending, descending }
