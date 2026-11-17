// test/widget/vitality_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/section_header.dart';
import 'package:kiolog/shared/widgets/module_icon_badge.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.of(KiologThemeId.claro),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('VitalityProgressBar', () {
    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(value: 0.5)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('clamps value between 0 and 1', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(value: 1.5)));
      final widget = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(widget.value, equals(1.0));
    });

    testWidgets('clamps negative value to 0', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(value: -0.5)));
      final widget = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(widget.value, equals(0.0));
    });

    testWidgets('uses custom color when provided', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(
              value: 0.5, color: Color(0xFFAFC7FF))));
      final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.color, equals(const Color(0xFFAFC7FF)));
    });
  });

  group('VitalityCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
          _wrap(VitalityCard(
              onTap: () => tapped = true,
              child: const Text('tap me'))));
      await tester.tap(find.text('tap me'));
      expect(tapped, isTrue);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
          _wrap(const SectionHeader(title: 'Módulos')));
      expect(find.text('Módulos'), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
          _wrap(SectionHeader(
              title: 'T',
              actionLabel: 'Ver',
              onAction: () => pressed = true)));
      await tester.tap(find.text('Ver'));
      expect(pressed, isTrue);
    });
  });

  group('ModuleIconBadge', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
          _wrap(const ModuleIconBadge(
              icon: Icons.water_drop, color: Color(0xFFAFC7FF))));
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });
  });

  group('StatChip', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(
          _wrap(const StatChip(value: '85%', label: 'Adherencia')));
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Adherencia'), findsOneWidget);
    });
  });
}
