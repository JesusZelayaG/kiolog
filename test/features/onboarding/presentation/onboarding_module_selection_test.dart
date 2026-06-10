import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ModuleSelectionHarness extends StatefulWidget {
  const _ModuleSelectionHarness();

  @override
  State<_ModuleSelectionHarness> createState() =>
      _ModuleSelectionHarnessState();
}

class _ModuleSelectionHarnessState extends State<_ModuleSelectionHarness> {
  final Set<String> _active = {'nutrition', 'water', 'exercise'};

  bool get _canProceed => _active.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (final m in ['nutrition', 'water', 'exercise'])
              SwitchListTile(
                key: Key('module_switch_$m'),
                title: Text(m),
                value: _active.contains(m),
                onChanged: (_active.length == 1 && _active.contains(m))
                    ? null
                    : (val) => setState(() {
                          if (val) {
                            _active.add(m);
                          } else {
                            _active.remove(m);
                          }
                        }),
              ),
            TextButton(
              key: const Key('next_btn'),
              onPressed: _canProceed ? () {} : null,
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Onboarding module selection step', () {
    testWidgets('all modules enabled by default', (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_nutrition'))).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_water'))).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_exercise'))).value,
        isTrue,
      );
    });

    testWidgets('toggling off a module disables its switch', (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_exercise'))).value,
        isFalse,
      );
    });

    testWidgets('last remaining module switch cannot be turned off',
        (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('module_switch_nutrition')));
      expect(tile.onChanged, isNull);
    });

    testWidgets('next button enabled when at least one module active',
        (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      final btn = tester.widget<TextButton>(find.byKey(const Key('next_btn')));
      expect(btn.onPressed, isNotNull);
    });
  });
}
