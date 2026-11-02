import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:thermion_flutter/thermion_flutter.dart';

import '../../domain/body_calibration.dart';

const _model = 'assets/models/anatomy_body.glb';
const _calibrationAsset = 'assets/models/anatomy_body.json';
const _idleDelay = Duration(milliseconds: 400);
const _cameraDistance = 2.9;

// Filament reads the background as linear light, then encodes it for the screen.
Color _toLinear(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return Color.from(
    alpha: 1,
    red: channel(color.r),
    green: channel(color.g),
    blue: channel(color.b),
  );
}

/// Modelo 3D del cuerpo con las medidas dadas. Se gira arrastrando.
class BodyViewer extends StatefulWidget {
  const BodyViewer({
    super.key,
    required this.sex,
    required this.perimetersCm,
    required this.heightCm,
    required this.fatPercent,
    required this.showFat,
  });

  final BodySex sex;
  final Map<String, double?> perimetersCm;
  final double heightCm;
  final double? fatPercent;
  final bool showFat;

  @override
  State<BodyViewer> createState() => _BodyViewerState();
}

class _BodyViewerState extends State<BodyViewer> {
  BodyCalibration? _calibration;
  ThermionAsset? _asset;
  ThermionViewer? _viewer;
  Timer? _idle;
  // Each mesh with the morph names it carries, in GLB order.
  final Map<ThermionEntity, List<String>> _meshes = {};
  bool _applying = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_calibrationAsset).then((source) {
      if (!mounted) return;
      _calibration = BodyCalibration.parse(source);
      _apply();
    });
  }

  @override
  void didUpdateWidget(BodyViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _apply();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  // Renders only while something changes, so the GPU rests on a still body.
  void _wake() {
    _viewer?.setRendering(true);
    _idle?.cancel();
    _idle = Timer(_idleDelay, () => _viewer?.setRendering(false));
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
    _asset = asset;
    await _apply();
  }

  // Coalesce changes so a slow frame never queues stale weights.
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
      _wake();
      final shape = calibration.solve(
        sex: widget.sex,
        perimetersCm: widget.perimetersCm,
        heightCm: widget.heightCm,
        fatPercent: widget.fatPercent,
      );
      await asset.setTransform(Matrix4.diagonal3Values(shape.scale, shape.scale, shape.scale));
      for (final MapEntry(key: mesh, value: names) in _meshes.entries) {
        await asset.setMorphTargetWeights(mesh, [
          for (final name in names)
            !widget.showFat && calibration.fat.contains(name) ? 0.0 : shape.weights[name]!,
        ]);
      }
    } while (_dirty && mounted);
    _applying = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _wake(),
      onPointerMove: (_) => _wake(),
      child: ViewerWidget(
        assetPath: _model,
        transformToUnitCube: false,
        background: _toLinear(Theme.of(context).colorScheme.surface),
        initialCameraPosition: Vector3(0, 0, _cameraDistance),
        initial: const Center(child: CircularProgressIndicator()),
        onViewerAvailable: _onViewer,
        onAssetLoaded: _onAsset,
      ),
    );
  }
}
