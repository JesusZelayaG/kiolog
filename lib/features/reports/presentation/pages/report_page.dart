import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/report_repository.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportBloc(getIt<ReportRepository>()),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateRangeSelector(context),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context.read<ReportBloc>().add(
                      ReportGenerated(start: _range.start, end: _range.end),
                    );
              },
              icon: const Icon(Icons.assessment),
              label: const Text('Generar reporte'),
            ),
            const SizedBox(height: 24),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, state) {
                if (state.status == ReportStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ReportStatus.failure) {
                  return Text('Error: ${state.error}');
                }
                if (state.status == ReportStatus.success && state.data != null) {
                  return _buildReportContent(context, state.data!);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: const Text('Período'),
        subtitle: Text(
          '${DateFormat.yMMMd('es').format(_range.start)} – ${DateFormat.yMMMd('es').format(_range.end)}',
        ),
        trailing: const Icon(Icons.edit),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            initialDateRange: _range,
          );
          if (picked != null) {
            setState(() => _range = picked);
          }
        },
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportData data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resumen', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Agua',
          value: '${(data.waterCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.waterGoalDays} / ${data.waterTotalDays} días meta',
        ),
        _MetricCard(
          label: 'Nutrición',
          value: '${(data.nutritionCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.mealsLogged} / ${data.mealsTotal} comidas',
        ),
        _MetricCard(
          label: 'Ejercicio',
          value: '${(data.exerciseCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.exerciseDays} / ${data.exerciseTotalDays} días',
        ),
        if (data.sleepAverage != null)
          _MetricCard(
            label: 'Sueño promedio',
            value: '${data.sleepAverage!.toStringAsFixed(1)} h',
            subtitle: 'Por noche',
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _exportPdf(data),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF'),
        ),
      ],
    );
  }

  Future<void> _exportPdf(ReportData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Kiolog — Reporte de Salud',
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(
              '${DateFormat.yMMMd('es').format(data.start)} – ${DateFormat.yMMMd('es').format(data.end)}',
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),
            _pdfMetric('Cumplimiento de agua',
                '${(data.waterCompliance * 100).toStringAsFixed(0)}%'),
            _pdfMetric('Cumplimiento de nutrición',
                '${(data.nutritionCompliance * 100).toStringAsFixed(0)}%'),
            _pdfMetric('Cumplimiento de ejercicio',
                '${(data.exerciseCompliance * 100).toStringAsFixed(0)}%'),
            if (data.sleepAverage != null)
              _pdfMetric('Sueño promedio',
                  '${data.sleepAverage!.toStringAsFixed(1)} h'),
            if (data.weightLogs.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Evolución de peso:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...data.weightLogs.map((log) => pw.Text(
                  '  ${DateFormat.yMMMd('es').format(log.date)}: ${log.weightKg} kg')),
            ],
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kiolog_reporte.pdf');
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte Kiolog',
      );
    }
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}
