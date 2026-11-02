import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';

/// Acepta la coma decimal del teclado y descarta vacíos, ceros y negativos.
double? parseMeasure(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value > 0 ? value : null;
}

/// Abre el formulario de consulta. Devuelve null si se cancela.
Future<Measurement?> showMeasurementForm(
  BuildContext context, {
  Measurement? initial,
}) =>
    showDialog<Measurement>(
      context: context,
      builder: (_) => _MeasurementForm(initial: initial),
    );

class _Field {
  const _Field(this.label, this.read);

  final String label;
  final double? Function(Measurement m) read;
}

const _weight = 'Peso (kg)';
const _height = 'Talla (cm)';
final _fields = <_Field>[
  _Field(_weight, (m) => m.weightKg),
  _Field(_height, (m) => m.heightCm),
  _Field('Brazo flex (cm)', (m) => m.armFlexedCm),
  _Field('Brazo relaj (cm)', (m) => m.armRelaxedCm),
  _Field('Cintura (cm)', (m) => m.waistCm),
  _Field('Cadera (cm)', (m) => m.hipCm),
  _Field('Pantorrilla (cm)', (m) => m.calfCm),
  _Field('Abdomen bajo (cm)', (m) => m.lowerAbdomenCm),
  _Field('Muslo (cm)', (m) => m.thighCm),
  _Field('Glúteo (cm)', (m) => m.midGluteusCm),
  _Field('Tórax (cm)', (m) => m.chestCm),
  _Field('% Grasa', (m) => m.bodyFatPct),
  _Field('Masa magra (kg)', (m) => m.leanMassKg),
  _Field('Masa visceral', (m) => m.visceralMass),
];

class _MeasurementForm extends StatefulWidget {
  const _MeasurementForm({this.initial});

  final Measurement? initial;

  @override
  State<_MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends State<_MeasurementForm> {
  late final Map<String, TextEditingController> _controllers;
  late DateTime _date;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final now = DateTime.now();
    _date = initial?.date.toUtc() ?? DateTime.utc(now.year, now.month, now.day);
    _controllers = {
      for (final field in _fields)
        field.label: TextEditingController(
          text: initial == null ? '' : '${field.read(initial) ?? ''}',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _value(String label) => parseMeasure(_controllers[label]!.text);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final weight = _value(_weight);
    final height = _value(_height);
    if (weight == null || height == null) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.pop(
      context,
      Measurement(
        id: widget.initial?.id ?? 0,
        date: _date,
        weightKg: weight,
        heightCm: height,
        armFlexedCm: _value('Brazo flex (cm)'),
        armRelaxedCm: _value('Brazo relaj (cm)'),
        waistCm: _value('Cintura (cm)'),
        hipCm: _value('Cadera (cm)'),
        calfCm: _value('Pantorrilla (cm)'),
        lowerAbdomenCm: _value('Abdomen bajo (cm)'),
        thighCm: _value('Muslo (cm)'),
        midGluteusCm: _value('Glúteo (cm)'),
        chestCm: _value('Tórax (cm)'),
        bodyFatPct: _value('% Grasa'),
        leanMassKg: _value('Masa magra (kg)'),
        visceralMass: _value('Masa visceral'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva consulta' : 'Editar consulta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(DateFormat('dd/MM/yyyy').format(_date)),
              subtitle: const Text('Fecha de la consulta'),
              onTap: _pickDate,
            ),
            for (final field in _fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controllers[field.label],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: field.label,
                    errorText: _showErrors &&
                            (field.label == _weight || field.label == _height) &&
                            _value(field.label) == null
                        ? 'Campo obligatorio'
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
