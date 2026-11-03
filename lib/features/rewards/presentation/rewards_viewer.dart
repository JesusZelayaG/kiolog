import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

const _model = 'assets/models/rewards.glb';
const _idleDelay = Duration(milliseconds: 400);

/// El cuarto se centra en el origen, donde mira y gira la cámara.
final _roomCenter = Vector3(-0.1, 0.85, -0.75);
final _cameraPosition = Vector3(3.25, 2.2, 4.2);

/// Las piezas ocultas van a una capa que no se dibuja.
const _hiddenLayer = VisibilityLayers.LAYER_5;

Color _toLinear(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return Color.from(alpha: 1, red: channel(color.r), green: channel(color.g), blue: channel(color.b));
}

/// El avatar en su cuarto, mostrando solo las piezas de [visible].
class RewardsViewer extends StatefulWidget {
  const RewardsViewer({super.key, required this.visible});

  final Set<String> visible;

  @override
  State<RewardsViewer> createState() => _RewardsViewerState();
}

class _RewardsViewerState extends State<RewardsViewer> {
  ThermionAsset? _asset;
  ThermionViewer? _viewer;
  Timer? _idle;
  final Map<String, ThermionEntity> _parts = {};
  bool _applying = false;
  bool _dirty = false;

  @override
  void didUpdateWidget(RewardsViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _apply();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

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
    await viewer.setLayerVisibility(_hiddenLayer, false);
    await viewer.addDirectLight(DirectLight.sun(
      intensity: 90000,
      direction: Vector3(-0.5, -0.8, -0.6).normalized(),
      castShadows: false,
    ));
    for (final (position, lumens) in [
      (Vector3(3, 2.5, 3.5), 4000000.0),
      (Vector3(-1, 2.5, 2), 2500000.0),
    ]) {
      await viewer.addDirectLight(DirectLight.point(
        intensity: lumens,
        position: position,
        falloffRadius: 8,
      ));
    }
  }

  Future<void> _onAsset(ThermionViewer viewer, ThermionAsset asset) async {
    final entities = await asset.getChildEntities();
    final names = await asset.getChildEntityNames();
    for (var i = 0; i < entities.length; i++) {
      final name = names[i];
      if (name != null) _parts[name] = entities[i];
    }
    await asset.setTransform(Matrix4.translation(-_roomCenter));
    if (!mounted) return;
    _asset = asset;
    await _apply();
  }

  Future<void> _apply() async {
    if (_applying) {
      _dirty = true;
      return;
    }
    final asset = _asset;
    if (asset == null) return;
    _applying = true;
    do {
      _dirty = false;
      _wake();
      for (final MapEntry(key: name, value: entity) in _parts.entries) {
        await asset.setVisibilityLayer(
          entity,
          widget.visible.contains(name) ? VisibilityLayers.DEFAULT_ASSET : _hiddenLayer,
        );
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
        background: _toLinear(Theme.of(context).colorScheme.surfaceContainerHigh),
        initialCameraPosition: _cameraPosition,
        initial: const Center(child: CircularProgressIndicator()),
        onViewerAvailable: _onViewer,
        onAssetLoaded: _onAsset,
      ),
    );
  }
}
