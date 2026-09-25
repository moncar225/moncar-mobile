/// Formats d'affichage en français (heures, dates, durées).
library;

String two(int n) => n.toString().padLeft(2, '0');

/// « 08:07 »
String fmtTime(DateTime? d) =>
    d == null ? '—' : '${two(d.hour)}:${two(d.minute)}';

const _days = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « Jeudi 25 septembre »
String fmtLongDate(DateTime d) {
  final s = '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  return s[0].toUpperCase() + s.substring(1);
}

/// « 25/09 · 08:07 »
String fmtShortDateTime(DateTime d) =>
    '${two(d.day)}/${two(d.month)} · ${fmtTime(d)}';

/// « il y a 5 min », « il y a 2 h », « à l'instant »
String fmtAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 45) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return fmtShortDateTime(d);
}

/// « 42 180 » (séparateur de milliers français).
String fmtInt(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String plural(int n, String singular, [String? pluralForm]) =>
    '$n ${n > 1 ? (pluralForm ?? '${singular}s') : singular}';
