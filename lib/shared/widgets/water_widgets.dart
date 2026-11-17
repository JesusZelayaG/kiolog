import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiolog/core/theme/app_theme.dart';

/// Litros con un decimal si hace falta: 3000 → "3", 2500 → "2.5".
String litersLabel(int ml) {
  final liters = ml / 1000;
  return liters == liters.roundToDouble() ? liters.toStringAsFixed(0) : liters.toStringAsFixed(1);
}

/// El agua que llena una tarjeta: dos olas desfasadas sobre el nivel.
class WavePainter extends CustomPainter {
  WavePainter({required this.level, required this.phase, required this.front, required this.back});

  /// De 0 (vacía) a 1 (llena).
  final double level;

  /// De 0 a 1; avanzarla mueve las olas.
  final double phase;
  final List<Color> front;
  final Color back;

  Path _wave(Size size, double y, double amplitude, double length, double shift) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 4; x += 4) {
      path.lineTo(x, y + amplitude * math.sin((x / length + shift) * 2 * math.pi));
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final y = size.height * (1 - level);
    canvas.drawPath(_wave(size, y - 3, 4, size.width * 0.5, -phase), Paint()..color = back);
    final paint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: front)
          .createShader(Rect.fromLTWH(0, y, size.width, math.max(1, size.height - y)));
    canvas.drawPath(_wave(size, y + 1, 5, size.width * 0.66, phase), paint);
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.level != level || old.phase != phase || old.front != front || old.back != back;
}

enum _Unit { ml, liters }

/// Pide una cantidad de agua en ml o litros y la devuelve en ml; null si se
/// canceló. Tocar un atajo la devuelve de una vez.
Future<int?> showWaterAmountSheet(
  BuildContext context, {
  String title = '¿Cuánto tomaste?',
  String action = 'Agregar',
  List<int> presets = const [250, 500, 750, 1000],
  int? initialMl,
  bool startInLiters = false,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AmountSheet(
        title: title,
        action: action,
        presets: presets,
        initialMl: initialMl,
        startInLiters: startInLiters,
      ),
    );

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.action,
    required this.presets,
    required this.initialMl,
    required this.startInLiters,
  });

  final String title;
  final String action;
  final List<int> presets;
  final int? initialMl;
  final bool startInLiters;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late _Unit _unit = widget.startInLiters ? _Unit.liters : _Unit.ml;
  late final _controller = TextEditingController(text: _format(widget.initialMl));

  String _format(int? ml) {
    if (ml == null) return '';
    return _unit == _Unit.ml ? '$ml' : litersLabel(ml);
  }

  /// La cantidad escrita, en ml; null si no es válida.
  int? get _ml {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    final ml = (_unit == _Unit.ml ? value : value * 1000).round();
    return ml > 0 && ml <= 20000 ? ml : null;
  }

  void _switchUnit(_Unit unit) {
    final ml = _ml;
    setState(() => _unit = unit);
    _controller.text = _format(ml);
  }

  String _presetLabel(int ml) => ml >= 1000 ? '${litersLabel(ml)} L' : '$ml ml';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final ml = _ml;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in widget.presets)
                  ActionChip(
                    avatar: Icon(Icons.water_drop, size: 16, color: kc.waterInk),
                    label: Text(_presetLabel(preset)),
                    backgroundColor: kc.waterWash,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(color: kc.waterInk, fontWeight: FontWeight.w700),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, preset);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.initialMl == null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
                    decoration: InputDecoration(
                      labelText: 'Otra cantidad',
                      hintText: _unit == _Unit.ml ? '350' : '1.5',
                      suffixText: _unit == _Unit.ml ? 'ml' : 'L',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_ml != null) Navigator.pop(context, _ml);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<_Unit>(
                  segments: const [
                    ButtonSegment(value: _Unit.ml, label: Text('ml')),
                    ButtonSegment(value: _Unit.liters, label: Text('L')),
                  ],
                  selected: {_unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => _switchUnit(set.first),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: ml == null ? null : () => Navigator.pop(context, ml),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(ml == null ? widget.action : '${widget.action} ${_presetLabel(ml)}'),
            ),
            if (_controller.text.isNotEmpty && ml == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Escribe una cantidad entre 1 ml y 20 L',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
