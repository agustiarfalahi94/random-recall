/// Returns a compact ISO date string for [d] in the form 'yyyy-MM-dd'.
/// Used for day-boundary comparisons in streak, plan, and ad services.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
