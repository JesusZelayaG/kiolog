import 'dart:convert';

enum BodySex { male, female }

/// Morph weights for one body, keyed by the morph names in the GLB.
class BodyShape {
  const BodyShape({required this.weights, required this.scale});

  final Map<String, double> weights;

  /// Uniform scale that takes the model to the person's height.
  final double scale;
}

/// Turns ficha measurements into morph weights, using the tape readings that
/// tools/body_model/anatomy/fit_measures.py stored next to the model.
class BodyCalibration {
  BodyCalibration._(this.heightCm, this.sites, this.shapes, this.fat, this._bySex);

  factory BodyCalibration.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    _SexTable table(String key) {
      final t = json[key] as Map<String, dynamic>;
      return _SexTable(_vector(t['base']), _matrix(t['shape']), _matrix(t['fat']));
    }

    return BodyCalibration._(
      (json['heightCm'] as num).toDouble(),
      List<String>.from(json['sites'] as List),
      List<String>.from(json['shapes'] as List),
      List<String>.from(json['fat'] as List),
      {BodySex.male: table('male'), BodySex.female: table('female')},
    );
  }

  static const _femaleMorph = 'femenino';
  static const _minWeight = -3.0;
  static const _maxWeight = 4.0;
  static const _passes = 40;
  // Essential fat to very high, by sex: the % that maps to pad weights 0 and 1.
  static const _fatRange = {BodySex.male: (8.0, 35.0), BodySex.female: (15.0, 42.0)};
  // Where each sex stores fat: abdomen, pecho, muslo.
  static const _fatShare = {
    BodySex.male: [1.0, 0.65, 0.65],
    BodySex.female: [0.65, 1.0, 1.0],
  };

  final double heightCm;
  final List<String> sites;
  final List<String> shapes;
  final List<String> fat;
  final Map<BodySex, _SexTable> _bySex;

  /// [perimetersCm] may lack any entry of [sites]: that site keeps the model's
  /// own size. The fat pads take their share of each perimeter and the muscles
  /// fill the rest, so a higher [fatPercent] at the same perimeters leaves less
  /// muscle. Without [fatPercent] the pads stay hidden.
  BodyShape solve({
    required BodySex sex,
    required Map<String, double?> perimetersCm,
    required double heightCm,
    double? fatPercent,
  }) {
    final table = _bySex[sex]!;
    final fatWeights = fatPercent == null
        ? List<double>.filled(fat.length, 0)
        : _fatWeights(sex, fatPercent);
    final toModel = this.heightCm / heightCm;
    final goal = [
      for (var site = 0; site < sites.length; site++)
        switch (perimetersCm[sites[site]]) {
          final cm? => cm * toModel - table.base[site] - _dot(table.fat[site], fatWeights),
          null => 0.0,
        },
    ];
    final w = List<double>.filled(shapes.length, 0);
    for (var pass = 0; pass < _passes; pass++) {
      for (var i = 0; i < w.length; i++) {
        final others = _dot(table.shape[i], w) - table.shape[i][i] * w[i];
        w[i] = ((goal[i] - others) / table.shape[i][i])
            .clamp(_minWeight, _maxWeight);
      }
    }
    return BodyShape(
      weights: {
        for (var i = 0; i < shapes.length; i++) shapes[i]: w[i],
        for (var i = 0; i < fat.length; i++) fat[i]: fatWeights[i],
        _femaleMorph: sex == BodySex.female ? 1 : 0,
      },
      scale: heightCm / this.heightCm,
    );
  }

  List<double> _fatWeights(BodySex sex, double percent) {
    final (low, high) = _fatRange[sex]!;
    final level = ((percent - low) / (high - low)).clamp(0.0, 1.0);
    return [for (final share in _fatShare[sex]!) level * share];
  }

  static double _dot(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  static List<double> _vector(Object? list) =>
      [for (final v in list! as List) (v as num).toDouble()];

  static List<List<double>> _matrix(Object? list) =>
      [for (final row in list! as List) _vector(row)];
}

class _SexTable {
  _SexTable(this.base, this.shape, this.fat);

  final List<double> base;
  final List<List<double>> shape;
  final List<List<double>> fat;
}
