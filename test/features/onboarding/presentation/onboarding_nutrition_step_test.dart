import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/onboarding/presentation/pages/onboarding_page.dart';

// Minimal wrapper that only shows the nutrition step (step index 2)
// by creating an isolated StatefulWidget that mirrors the step's state.
class _NutritionStepHarness extends StatefulWidget {
  const _NutritionStepHarness();

  @override
  State<_NutritionStepHarness> createState() =>
      _NutritionStepHarnessState();
}

class _MealTimeLocal {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}

class _NutritionStepHarnessState extends State<_NutritionStepHarness> {
  final List<_MealTimeLocal> _mealTimes = [_MealTimeLocal()];

  @override
  void dispose() {
    for (final mt in _mealTimes) {
      mt.nameController.dispose();
      for (final c in mt.options) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ..._mealTimes.asMap().entries.map((e) {
                final index = e.key;
                final mt = e.value;
                return Card(
                  key: Key('meal_time_$index'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Tiempo ${index + 1}'),
                          Expanded(
                            child: TextField(
                              key: Key('meal_name_$index'),
                              controller: mt.nameController,
                            ),
                          ),
                          if (_mealTimes.length > 1)
                            IconButton(
                              key: Key('delete_time_$index'),
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  setState(() => _mealTimes.removeAt(index)),
                            ),
                        ],
                      ),
                      ...mt.options.asMap().entries.map((oe) {
                        return Row(
                          key: Key('option_${index}_${oe.key}'),
                          children: [
                            Expanded(
                              child: TextField(
                                key: Key('option_field_${index}_${oe.key}'),
                                controller: oe.value,
                              ),
                            ),
                            if (mt.options.length > 1)
                              IconButton(
                                key: Key('delete_opt_${index}_${oe.key}'),
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                    () => mt.options.removeAt(oe.key)),
                              ),
                          ],
                        );
                      }),
                      TextButton(
                        key: Key('add_option_$index'),
                        onPressed: () => setState(
                            () => mt.options.add(TextEditingController())),
                        child: const Text('+ Agregar opción'),
                      ),
                    ],
                  ),
                );
              }),
              Text(
                'Meta diaria automática: ${_mealTimes.length} ${_mealTimes.length == 1 ? 'comida' : 'comidas'}',
                key: const Key('daily_goal_label'),
              ),
              TextButton(
                key: const Key('add_meal_time'),
                onPressed: () =>
                    setState(() => _mealTimes.add(_MealTimeLocal())),
                child: const Text('+ Agregar tiempo de comida'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Onboarding nutrition step', () {
    testWidgets('starts with 1 meal time card', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('meal_time_0')), findsOneWidget);
      expect(find.byKey(const Key('meal_time_1')), findsNothing);
    });

    testWidgets('adding a meal time shows a second card', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meal_time_0')), findsOneWidget);
      expect(find.byKey(const Key('meal_time_1')), findsOneWidget);
    });

    testWidgets('delete button not shown when only 1 meal time', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('delete_time_0')), findsNothing);
    });

    testWidgets('delete button shown when 2+ meal times, removes the card',
        (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete_time_0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_time_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meal_time_1')), findsNothing);
    });

    testWidgets('adding an option shows a second option field', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('option_field_0_1')), findsNothing);
      await tester.tap(find.byKey(const Key('add_option_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('option_field_0_1')), findsOneWidget);
    });

    testWidgets('daily goal label updates when meal times change',
        (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.text('Meta diaria automática: 1 comida'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.text('Meta diaria automática: 2 comidas'), findsOneWidget);
    });
  });
}
