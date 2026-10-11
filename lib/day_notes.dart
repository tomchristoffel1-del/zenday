/// Tagesnotizen und ihre Kategorien.
///
/// Die Kategorien werden lokal über Stichwörter aus dem Text erkannt (offline,
/// ohne KI-Dienst). Was die Erkennung falsch macht, korrigiert man per Tipp auf
/// die Kategorie: das wird als manuelle Ergänzung bzw. Abwahl gespeichert, damit
/// es beim nächsten Bearbeiten des Texts nicht wieder überschrieben wird.
library;

enum Polarity { positive, negative, neutral }

class NoteCategory {
  final String id;
  final String label;
  final String emoji;
  final Polarity polarity;

  /// Kleingeschrieben. Treffer nur am Wortanfang, d. h. "konzentriert" passt
  /// nicht in "unkonzentriert"; Endungen dürfen folgen ("müde" → "müder").
  final List<String> keywords;

  const NoteCategory(this.id, this.label, this.emoji, this.polarity, this.keywords);
}

const noteCategories = <NoteCategory>[
  NoteCategory('sick', 'Krank', '🤒', Polarity.negative, [
    'krank', 'erkält', 'fieber', 'grippe', 'husten', 'schnupfen', 'halsschmerz', 'halsweh',
    'kopfschmerz', 'kopfweh', 'migräne', 'übel', 'magen', 'infekt', 'corona', 'covid', 'bauchschmerz',
  ]),
  NoteCategory('tired', 'Müde', '😴', Polarity.negative, [
    'müde', 'erschöpft', 'kaputt', 'schlecht geschlafen', 'nicht gut geschlafen', 'wenig geschlafen',
    'wenig schlaf', 'kaum geschlafen', 'verschlafen', 'schlapp', 'übermüdet', 'k.o.',
  ]),
  NoteCategory('rested', 'Gut geschlafen', '🛌', Polarity.positive, [
    'gut geschlafen', 'ausgeschlafen', 'erholt', 'viel geschlafen', 'lange geschlafen',
  ]),
  NoteCategory('badMood', 'Schlechte Laune', '😞', Polarity.negative, [
    'schlechte laune', 'mies', 'genervt', 'traurig', 'frust', 'wütend', 'sauer', 'gereizt',
    'down', 'lustlos', 'demotiviert', 'unmotiviert', 'keine lust', 'schlecht drauf',
  ]),
  NoteCategory('goodMood', 'Gute Laune', '😊', Polarity.positive, [
    'gute laune', 'glücklich', 'zufrieden', 'happy', 'motiviert', 'entspannt', 'super tag',
    'toller tag', 'guter tag', 'schöner tag', 'froh', 'gut drauf', 'energie',
  ]),
  NoteCategory('unfocused', 'Unkonzentriert', '🌫️', Polarity.negative, [
    'unkonzentriert', 'keine konzentration', 'schlechte konzentration', 'konzentrationsprobleme',
    'abgelenkt', 'prokrastin', 'aufgeschoben', 'handy', 'social media', 'instagram', 'tiktok',
    'youtube', 'nicht fokussiert', 'ineffizient', 'zeit verschwendet', 'nichts geschafft',
  ]),
  NoteCategory('focused', 'Konzentriert', '🎯', Polarity.positive, [
    'konzentriert', 'fokussiert', 'gute konzentration', 'flow', 'produktiv', 'effizient',
    'viel geschafft', 'gut gelernt', 'gut vorangekommen',
  ]),
  NoteCategory('stress', 'Stress', '😰', Polarity.negative, [
    'stress', 'gestresst', 'unter druck', 'überfordert', 'angst', 'nervös', 'panik', 'hektik', 'hektisch',
  ]),
  NoteCategory('badFood', 'Schlecht gegessen', '🍔', Polarity.negative, [
    'schlecht gegessen', 'ungesund', 'fast food', 'fastfood', 'pizza', 'burger', 'döner', 'süßigkeiten',
    'zu viel gegessen', 'nichts gegessen', 'kaum gegessen', 'zucker',
  ]),
  NoteCategory('goodFood', 'Gesund gegessen', '🥗', Polarity.positive, [
    'gesund gegessen', 'gut gegessen', 'salat', 'gemüse', 'meal prep', 'mealprep', 'gekocht', 'obst',
  ]),
  NoteCategory('sport', 'Sport', '🏃', Polarity.positive, [
    'sport', 'training', 'trainiert', 'gym', 'fitness', 'workout', 'joggen', 'gejoggt', 'laufen gewesen', 'lauftraining',
    'schwimmen', 'fahrrad', 'radfahren', 'spaziergang', 'spazieren',
  ]),
  NoteCategory('alcohol', 'Alkohol', '🍺', Polarity.negative, [
    'alkohol', 'bier', 'wein', 'getrunken', 'kater', 'betrunken', 'verkatert',
  ]),
  NoteCategory('social', 'Freunde & Familie', '👥', Polarity.neutral, [
    'freunde', 'freundin', 'freund', 'familie', 'eltern', 'treffen', 'getroffen', 'besuch', 'party',
    'feiern', 'gefeiert', 'geburtstag',
  ]),
  NoteCategory('appointments', 'Termine & Unterwegs', '🚗', Polarity.neutral, [
    'termin', 'arzt', 'zahnarzt', 'unterwegs', 'reise', 'fahrt', 'bahn', 'im zug', 'umzug', 'behörde',
    'einkaufen', 'erledigungen',
  ]),
  NoteCategory('work', 'Arbeit', '💼', Polarity.neutral, [
    'arbeit', 'gearbeitet', 'schicht', 'job', 'arbeiten', 'kunde', 'meeting',
  ]),
];

final Map<String, NoteCategory> noteCategoryById = {for (final c in noteCategories) c.id: c};

bool _isLetter(String ch) => RegExp(r'[a-zäöüß]').hasMatch(ch);

/// Steht direkt vor dem Treffer eine Verneinung ("nicht müde", "kein Sport")?
bool _negatedBefore(String text, int index) {
  final before = text.substring(0, index).trimRight();
  final words = before.split(RegExp(r'\s+'));
  if (words.isEmpty) return false;
  final last = words.last;
  return const {'nicht', 'kein', 'keine', 'keinen', 'keiner', 'nie', 'ohne', 'kaum'}.contains(last);
}

bool _containsKeyword(String text, String keyword) {
  var from = 0;
  while (true) {
    final i = text.indexOf(keyword, from);
    if (i < 0) return false;
    final atWordStart = i == 0 || !_isLetter(text[i - 1]);
    // Die Verneinung ist bei Phrasen, die selbst mit "kein"/"nicht" beginnen, schon im Stichwort enthalten.
    if (atWordStart && !_negatedBefore(text, i)) return true;
    from = i + 1;
  }
}

/// Kategorien, die im Text erkannt werden.
Set<String> detectCategories(String text) {
  final t = text.toLowerCase();
  if (t.trim().isEmpty) return {};
  final result = <String>{};
  for (final c in noteCategories) {
    if (c.keywords.any((k) => _containsKeyword(t, k))) result.add(c.id);
  }
  return result;
}

class DayNote {
  String text;

  /// Manuell hinzugefügte bzw. abgewählte Kategorien (überschreiben die Erkennung).
  Set<String> added;
  Set<String> removed;

  DayNote({this.text = '', Set<String>? added, Set<String>? removed})
      : added = added ?? {},
        removed = removed ?? {};

  bool get isEmpty => text.trim().isEmpty && added.isEmpty;

  Set<String> get tags => {...detectCategories(text), ...added}.difference(removed);

  /// Kategorie per Tipp an-/abschalten.
  void toggle(String id) {
    final active = tags.contains(id);
    final auto = detectCategories(text).contains(id);
    if (active) {
      added.remove(id);
      if (auto) removed.add(id);
    } else {
      removed.remove(id);
      if (!auto) added.add(id);
    }
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (added.isNotEmpty) 'added': added.toList(),
        if (removed.isNotEmpty) 'removed': removed.toList(),
      };

  factory DayNote.fromJson(Map<String, dynamic> json) => DayNote(
        text: json['text'] as String? ?? '',
        added: {...(json['added'] as List? ?? const []).cast<String>()},
        removed: {...(json['removed'] as List? ?? const []).cast<String>()},
      );
}
