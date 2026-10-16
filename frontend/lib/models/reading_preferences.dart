import 'dart:convert';

enum ReadingContrast { standard, high, blackOnWhite, yellowOnBlack }

/// Local presentation choices. No account, medical or location data.
class ReadingPreferences {
  final double textSize, letterSpacing, lineHeight;
  final ReadingContrast contrast;
  final bool serif, highlightLinks, hideDecorativeImages;
  const ReadingPreferences({
    this.textSize = 1,
    this.letterSpacing = 0,
    this.lineHeight = 1,
    this.contrast = ReadingContrast.standard,
    this.serif = false,
    this.highlightLinks = false,
    this.hideDecorativeImages = false,
  });

  static double number(
          Object? value, double fallback, double min, double max) =>
      value is num && value.isFinite && value >= min && value <= max
          ? value.toDouble()
          : fallback;

  static Map<String, dynamic> decode(Object? value) {
    if (value is! String) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  factory ReadingPreferences.fromStorage(Object? value) {
    final data = decode(value);
    return ReadingPreferences(
      textSize: number(data['textSize'], 1, 1, 2),
      letterSpacing: number(data['letterSpacing'], 0, 0, 3),
      lineHeight: number(data['lineHeight'], 1, 1, 1.8),
      contrast: ReadingContrast.values.firstWhere(
        (mode) => mode.name == data['contrast'],
        orElse: () => ReadingContrast.standard,
      ),
      serif: data['serif'] == true,
      highlightLinks: data['highlightLinks'] == true,
      hideDecorativeImages: data['hideDecorativeImages'] == true,
    );
  }

  ReadingPreferences copyWith({
    double? textSize,
    double? letterSpacing,
    double? lineHeight,
    ReadingContrast? contrast,
    bool? serif,
    bool? highlightLinks,
    bool? hideDecorativeImages,
  }) =>
      ReadingPreferences(
        textSize: number(textSize ?? this.textSize, this.textSize, 1, 2),
        letterSpacing: number(
            letterSpacing ?? this.letterSpacing, this.letterSpacing, 0, 3),
        lineHeight:
            number(lineHeight ?? this.lineHeight, this.lineHeight, 1, 1.8),
        contrast: contrast ?? this.contrast,
        serif: serif ?? this.serif,
        highlightLinks: highlightLinks ?? this.highlightLinks,
        hideDecorativeImages: hideDecorativeImages ?? this.hideDecorativeImages,
      );

  Map<String, dynamic> toJson() => {
        'textSize': textSize,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'contrast': contrast.name,
        'serif': serif,
        'highlightLinks': highlightLinks,
        'hideDecorativeImages': hideDecorativeImages,
      };
}
