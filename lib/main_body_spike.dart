// Prueba técnica del modelo corporal 3D. Se lanza aparte de la app:
//   flutter run -t lib/main_body_spike.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kiolog/body_calibration.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

const _model = 'assets/models/anatomy_body.glb';
const _calibrationAsset = 'assets/models/anatomy_body.json';
const _heightKey = 'estatura';
const _fatKey = 'grasa';

class _Measure {
  const _Measure(this.key, this.label, this.value, this.min, this.max);

  final String key;
  final String label;
  final double value;
  final double min;
  final double max;
}

// Los valores iniciales salen de la ficha antropométrica.
const _measures = [
  _Measure(_heightKey, 'Estatura', 160, 140, 200),
  _Measure('pecho', 'Mesoesternal', 100, 70, 130),
  _Measure('cintura', 'Cintura', 85.5, 55, 125),
  _Measure('abdomen', 'Abdomen bajo', 89, 60, 130),
  _Measure('cadera', 'Cadera', 103.5, 75, 135),
  _Measure('brazo', 'Brazo relajado', 36, 22, 50),
  _Measure('muslo', 'Muslo medio', 55, 38, 75),
  _Measure('pantorrilla', 'Pantorrilla', 35, 26, 48),
  _Measure(_fatKey, '% Grasa', 27.6, 6, 45),
];

void main() => runApp(const MaterialApp(home: BodySpikePage()));

class BodySpikePage extends StatefulWidget {
  const BodySpikePage({super.key});

  @override
  State<BodySpikePage> createState() => _BodySpikePageState();
}

class _BodySpikePageState extends State<BodySpikePage> {
  BodySex _sex = BodySex.male;
  bool _showFat = true;
  BodyCalibration? _calibration;
  ThermionAsset? _asset;
  ThermionViewer? _viewer;
  Timer? _idle;
  // Each mesh with the morph names it carries, in GLB order.
  final Map<ThermionEntity, List<String>> _meshes = {};
  final Map<String, double> _values = {for (final m in _measures) m.key: m.value};
  int? _loadMs;
  int? _lastApplyMs;
  String _fps = '-';
  bool _applying = false;
  bool _dirty = false;
  final _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_calibrationAsset).then((source) {
      if (!mounted) return;
      setState(() => _calibration = BodyCalibration.parse(source));
      _apply();
    });
  }

  // Renders only while something changes, so the GPU rests on a still body.
  void _wake() {
    _viewer?.setRendering(true);
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 400), () {
      _viewer?.setRendering(false);
    });
  }

  Future<void> _onViewer(ThermionViewer viewer) async {
    _viewer = viewer;
    await viewer.setShadowsEnabled(false);
    await viewer.setBloom(false, 0);
    await viewer.setAntiAliasing(false, false, false);
    await viewer.addDirectLight(DirectLight.sun(
      intensity: 90000,
      direction: Vector3(-0.4, -0.6, -1).normalized(),
      castShadows: false,
    ));
    // Filament uses a single sun, so point lights cover the rest of the orbit.
    for (final (position, lumens) in [
      (Vector3(0, 0.5, -2.5), 5000000.0),
      (Vector3(-2.5, 0.2, 0), 3000000.0),
      (Vector3(2.5, 0.2, 0), 3000000.0),
    ]) {
      await viewer.addDirectLight(DirectLight.point(
        intensity: lumens,
        position: position,
        falloffRadius: 6,
      ));
    }
  }

  Future<void> _onAsset(ThermionViewer viewer, ThermionAsset asset) async {
    for (final entity in await asset.getChildEntities()) {
      final morphs = await asset.getMorphTargetNames(entity: entity);
      if (morphs.isNotEmpty) _meshes[entity] = morphs;
    }
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _loadMs = _stopwatch.elapsedMilliseconds;
    });
    await _apply();
  }

  BodyShape _shape(BodyCalibration calibration) => calibration.solve(
        sex: _sex,
        perimetersCm: {for (final s in calibration.sites) s: _values[s]!},
        heightCm: _values[_heightKey]!,
        fatPercent: _values[_fatKey]!,
      );

  // Coalesce slider events so a slow frame never queues stale weights.
  Future<void> _apply() async {
    if (_applying) {
      _dirty = true;
      return;
    }
    final asset = _asset;
    final calibration = _calibration;
    if (asset == null || calibration == null) return;
    _applying = true;
    do {
      _dirty = false;
      final start = _stopwatch.elapsedMilliseconds;
      _wake();
      final shape = _shape(calibration);
      await asset.setTransform(Matrix4.diagonal3Values(shape.scale, shape.scale, shape.scale));
      for (final MapEntry(key: mesh, value: names) in _meshes.entries) {
        await asset.setMorphTargetWeights(mesh, [
          for (final name in names)
            !_showFat && calibration.fat.contains(name) ? 0.0 : shape.weights[name]!,
        ]);
      }
      if (mounted) {
        setState(() => _lastApplyMs = _stopwatch.elapsedMilliseconds - start);
      }
    } while (_dirty && mounted);
    _applying = false;
  }

  // Sweeps the waist for 5 s and counts the frames Flutter composites, each of
  // which carries a new Filament texture while the body is changing.
  Future<void> _measure() async {
    var frames = 0;
    var slow = 0;
    var buildUs = 0;
    var rasterUs = 0;
    void onTimings(List<FrameTiming> timings) {
      frames += timings.length;
      for (final t in timings) {
        buildUs += t.buildDuration.inMicroseconds;
        rasterUs += t.rasterDuration.inMicroseconds;
      }
      slow += timings
          .where((t) => t.totalSpan > const Duration(milliseconds: 34))
          .length;
    }

    final waist = _values['cintura']!;
    final start = _stopwatch.elapsedMilliseconds;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    while (_stopwatch.elapsedMilliseconds - start < 5000 && mounted) {
      final t = (_stopwatch.elapsedMilliseconds - start) / 1000;
      setState(() => _values['cintura'] = waist + 15 * math.sin(t * 3));
      await _apply();
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    _values['cintura'] = waist;
    await _apply();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final count = math.max(frames, 1);
    if (mounted) {
      setState(() => _fps = '${frames ~/ 5} fps, $slow lentos, '
          'build ${buildUs ~/ count ~/ 1000} ms, '
          'raster ${rasterUs ~/ count ~/ 1000} ms');
    }
    debugPrint('BODYTEST ${_sex.name} carga=$_loadMs ms $_fps');
  }

  void _setSex(BodySex sex) {
    setState(() => _sex = sex);
    _apply();
  }

  void _resetToFicha() {
    setState(() {
      for (final m in _measures) {
        _values[m.key] = m.value;
      }
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F4),
      body: SafeArea(
        child: Column(
          children: [
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Hombre'),
                  selected: _sex == BodySex.male,
                  onSelected: (_) => _setSex(BodySex.male),
                ),
                ChoiceChip(
                  label: const Text('Mujer'),
                  selected: _sex == BodySex.female,
                  onSelected: (_) => _setSex(BodySex.female),
                ),
                FilterChip(
                  label: const Text('Grasa'),
                  selected: _showFat,
                  onSelected: (v) {
                    setState(() => _showFat = v);
                    _apply();
                  },
                ),
                TextButton(onPressed: _resetToFicha, child: const Text('Ficha')),
              ],
            ),
            Expanded(
              child: Listener(
                onPointerDown: (_) => _wake(),
                onPointerMove: (_) => _wake(),
                child: ViewerWidget(
                  assetPath: _model,
                  transformToUnitCube: false,
                  background: const Color(0xFFFCF9F4),
                  initialCameraPosition: Vector3(0, 0, 2.9),
                  initial: const Center(child: CircularProgressIndicator()),
                  onViewerAvailable: _onViewer,
                  onAssetLoaded: _onAsset,
                ),
              ),
            ),
            FilledButton(
                onPressed: _asset == null ? null : _measure,
                child: Text('Medir 5 s ($_fps)')),
            Text('Carga: ${_loadMs ?? '-'} ms · '
                'Última deformación: ${_lastApplyMs ?? '-'} ms'),
            SizedBox(
              height: 200,
              child: ListView(
                children: [
                  for (final m in _measures)
                    Row(
                      children: [
                        SizedBox(
                          width: 165,
                          child: Text('  ${m.label} ${_values[m.key]!.toStringAsFixed(1)}'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _values[m.key]!,
                            min: m.min,
                            max: m.max,
                            onChanged: (v) {
                              setState(() => _values[m.key] = v);
                              _apply();
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
