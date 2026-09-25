/// The two ways the reader can write the Quran.
///
/// A script is a text and a font together, never a font alone: each font was
/// made for its own encoding of the Quran, and only that pairing puts every
/// mark where the mushaf has it. See QuranScriptRepository for the texts and
/// DESIGN.md for the fonts. Stored by name, so the order can grow without
/// breaking a saved choice.
enum QuranScript {
  /// The Madinah mushaf: KFGQPC HAFS Uthmanic Script.
  uthmani,

  /// The South Asian mushaf read across Pakistan and India: KFGQPC Nastaleeq.
  indopak;

  String get label => switch (this) {
        QuranScript.uthmani => 'Uthmani',
        QuranScript.indopak => 'IndoPak',
      };

  String get description => switch (this) {
        QuranScript.uthmani => 'As in the Madinah mushaf',
        QuranScript.indopak => 'As in the mushaf of Pakistan and India',
      };

  /// The font family declared for this script in pubspec.yaml.
  String get fontFamily => switch (this) {
        QuranScript.uthmani => 'QuranUthmani',
        QuranScript.indopak => 'QuranIndoPak',
      };

  /// The two faces are not the same size at the same point size: the
  /// Nastaleeq's letters sit smaller on their line. This keeps one text-size
  /// setting reading the same in both.
  double get sizeScale => switch (this) {
        QuranScript.uthmani => 1.0,
        QuranScript.indopak => 1.08,
      };

  /// Room the marks need above and below the line, as a multiple of the size.
  double get lineHeight => switch (this) {
        QuranScript.uthmani => 2.1,
        QuranScript.indopak => 2.2,
      };
}
