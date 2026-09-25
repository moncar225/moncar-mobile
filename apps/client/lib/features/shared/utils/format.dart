// ============================================================
// MON CAR — Utilitaires de formatage (portage de `utils.ts`)
// Montants FCFA, dates/heures en français, durées, distances.
// ============================================================

library;

import 'dart:math';

const List<String> _monthsFrShort = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const List<String> _monthsFrLong = [
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

const List<String> _daysFrShort = [
  'dim.',
  'lun.',
  'mar.',
  'mer.',
  'jeu.',
  'ven.',
  'sam.',
];

const List<String> _daysFrLong = [
  'dimanche',
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
];

DateTime _parseDate(String input) {
  // Accepte "2026-09-22" ou un horodatage ISO complet.
  final normalized = input.length == 10 ? '${input}T00:00:00' : input;
  return DateTime.parse(normalized);
}

// ----------------------------- Montants / FCFA -----------------------------

String _thousands(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final remaining = digits.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write(' ');
  }
  return n < 0 ? '-${buf.toString()}' : buf.toString();
}

/// Nombre avec séparateur de milliers français : « 12 450 ».
String formatNumber(int n) => _thousands(n);

/// Formate un montant entier FCFA : « 5 000 FCFA ».
String formatXOF(int amount) => '${_thousands(amount)} FCFA';

/// Montant compact pour les chips (ex. « 12k », « 1,2M »).
String formatXOFShort(int amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  }
  if (amount >= 1000) return '${(amount / 1000).round()}k';
  return '$amount';
}

// ----------------------------- Dates / Heures -----------------------------

/// "08:30" → "08:30" (tronque les secondes si présentes).
String formatTime(String time) => time.substring(0, 5);

/// « 22 sept. »
String formatDateShort(String date) {
  final d = _parseDate(date);
  return '${d.day} ${_monthsFrShort[d.month - 1]}';
}

/// « 22 septembre 2026 »
String formatDateLong(String date) {
  final d = _parseDate(date);
  return '${d.day} ${_monthsFrLong[d.month - 1]} ${d.year}';
}

/// « lun. 22 sept. »
String formatDateWithDay(String date) {
  final d = _parseDate(date);
  return '${_daysFrShort[d.weekday % 7]} ${d.day} ${_monthsFrShort[d.month - 1]}';
}

/// « lundi 22 septembre 2026 »
String formatDateFull(String date) {
  final d = _parseDate(date);
  return '${_daysFrLong[d.weekday % 7]} ${d.day} ${_monthsFrLong[d.month - 1]} ${d.year}';
}

/// « 26/08/2026 »
String formatDateNumeric(String date) {
  final d = _parseDate(date);
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Date du jour au format ISO "2026-09-22" (heure locale).
String todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Date à [days] jours du aujourd'hui, format ISO.
String dateOffset(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Horodatage ISO local (sans fuseau, équivalent `toISOString` du prototype).
String isoNow() => DateTime.now().toIso8601String();

/// Horodatage ISO local à [ms] millisecondes de maintenant.
String isoOffsetMs(int ms) =>
    DateTime.now().add(Duration(milliseconds: ms)).toIso8601String();

// ----------------------------- Durées -----------------------------

/// Minutes → « 2 h 15 ».
String formatDuration(int min) {
  final h = min ~/ 60;
  final m = min % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h ${m.toString().padLeft(2, '0')}';
}

/// Minutes → « 2h15 » compact.
String formatDurationShort(int min) {
  final h = min ~/ 60;
  final m = min % 60;
  if (h == 0) return '${m}min';
  return m == 0 ? '${h}h' : '$h h ${m.toString().padLeft(2, '0')}';
}

// ----------------------------- Distance -----------------------------

String formatDistance(double km) {
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

// ----------------------------- Temps relatif -----------------------------

String timeAgo(String iso) {
  final then = _parseDate(iso).millisecondsSinceEpoch;
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = now - then;
  final sec = diff ~/ 1000;
  if (sec < 60) return "à l'instant";
  final min = sec ~/ 60;
  if (min < 60) return 'il y a $min min';
  final h = min ~/ 60;
  if (h < 24) return 'il y a $h h';
  final days = h ~/ 24;
  if (days < 7) return 'il y a $days j';
  return formatDateShort(iso);
}

// ----------------------------- Divers -----------------------------

String initialsOf(String first, String last) =>
    '${first.isEmpty ? '' : first[0].toUpperCase()}'
    '${last.isEmpty ? '' : last[0].toUpperCase()}';

String generateReference(String prefix) {
  final part = _randBase36(6).toUpperCase();
  final num = 1000 + _rand.nextInt(9000);
  return '$prefix-$num-$part';
}

String generateIdempotencyKey() =>
    'idk_${DateTime.now().millisecondsSinceEpoch}_${_randBase36(10)}';

String generateId(String prefix) => '${prefix}_${_randBase36(10)}';

final _rand = Random();

String _randBase36(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(
    length,
    (_) => chars[_rand.nextInt(chars.length)],
  ).join();
}

/// Ajoute [min] minutes à une heure "HH:MM" et renvoie "HH:MM".
String addMinutesToTime(String base, int min) {
  final parts = base.split(':');
  final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + min;
  final h = (total % 1440) ~/ 60;
  final m = total % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Normalise une chaîne pour la recherche (minuscules, sans accents).
String normalizeSearch(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àáâãäå]', caseSensitive: false), 'a')
    .replaceAll(RegExp(r'[èéêë]', caseSensitive: false), 'e')
    .replaceAll(RegExp(r'[ìíîï]', caseSensitive: false), 'i')
    .replaceAll(RegExp(r'[òóôõö]', caseSensitive: false), 'o')
    .replaceAll(RegExp(r'[ùúûü]', caseSensitive: false), 'u')
    .replaceAll(RegExp(r'[ç]', caseSensitive: false), 'c');
