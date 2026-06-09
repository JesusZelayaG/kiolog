import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OnboardingView();
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 2: Water config
  String _waterUnit = 'bottle';
  int _containerMl = 1000;
  int _dailyGoalMl = 3000;

  // Step 3: Nutrition
  final _mealPlanNameController = TextEditingController(text: 'Mi Plan');
  final Map<String, List<TextEditingController>> _mealOptions = {
    'breakfast': [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ],
    'lunch': [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ],
    'dinner': [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ],
    'snack': [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ],
  };

  // Step 4: Exercise — días de rutina numerados (Día 1, Día 2, ...)
  final _exercisePlanNameController = TextEditingController(text: 'Mi Rutina');
  final List<_RoutineDay> _routineDays = [];

  // Step 5: Initial data
  final _weightController = TextEditingController();
  DateTime _startDate = DateTime.now();

  String _mealTypeLabel(String type) {
    return switch (type) {
      'breakfast' => 'Desayuno',
      'lunch' => 'Almuerzo',
      'dinner' => 'Cena',
      'snack' => 'Entrecomida',
      _ => type,
    };
  }



  @override
  void dispose() {
    _pageController.dispose();
    _mealPlanNameController.dispose();
    _exercisePlanNameController.dispose();
    _weightController.dispose();
    for (final list in _mealOptions.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    for (final day in _routineDays) {
      day.nameController.dispose();
      for (final e in day.exercises) {
        e.name.dispose();
        e.sets.dispose();
        e.reps.dispose();
        e.weight.dispose();
      }
    }
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    // Save water config
    await getIt<WaterRepository>().saveConfig(
      unitType: _waterUnit,
      containerMl: _containerMl,
      dailyGoalMl: _dailyGoalMl,
    );

    // Save nutrition plan
    final nutritionRepo = getIt<NutritionRepository>();
    final planId = await nutritionRepo.createPlan(_mealPlanNameController.text);
    for (final entry in _mealOptions.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        final text = entry.value[i].text.trim();
        if (text.isNotEmpty) {
          await nutritionRepo.addPlanOption(
            planId: planId,
            mealType: entry.key,
            optionNumber: i + 1,
            description: text,
          );
        }
      }
    }

    // Save exercise plan
    final exerciseRepo = getIt<ExerciseRepository>();
    final exercisePlanId =
        await exerciseRepo.createPlan(_exercisePlanNameController.text);
    for (int i = 0; i < _routineDays.length; i++) {
      final day = _routineDays[i];
      final routineName = day.nameController.text.trim().isEmpty
          ? 'Día ${i + 1}'
          : day.nameController.text.trim();
      final routineId = await exerciseRepo.addRoutine(
        planId: exercisePlanId,
        dayNumber: i + 1,
        routineName: routineName,
      );
      for (final ex in day.exercises) {
        final sets = int.tryParse(ex.sets.text) ?? 3;
        final reps = int.tryParse(ex.reps.text) ?? 10;
        final weight = double.tryParse(ex.weight.text);
        if (ex.name.text.isNotEmpty) {
          await exerciseRepo.addRoutineItem(
            routineId: routineId,
            exerciseName: ex.name.text,
            sets: sets,
            reps: reps,
            weightKg: weight,
          );
        }
      }
    }

    // Save initial weight
    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      await getIt<ProgressRepository>().addWeightLog(_startDate, weight);
    }

    // Mark onboarding complete
    await getIt<UserProfileDao>().completeOnboarding(_startDate);

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(theme),
                  _buildWaterStep(theme),
                  _buildNutritionStep(theme),
                  _buildExerciseStep(theme),
                  _buildInitialDataStep(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _prevStep,
                      child: const Text('Atrás'),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  FilledButton(
                    onPressed:
                        _currentStep == _totalSteps - 1 ? _finish : _nextStep,
                    child: Text(_currentStep == _totalSteps - 1
                        ? 'Finalizar'
                        : 'Siguiente'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Bienvenido a Kiolog',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Vamos a configurar tu bitácora de salud personal. Este proceso solo toma unos minutos.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Necesitamos que nos cuentes:\n'
            '• Cómo medirás tu agua\n'
            '• Tu plan de alimentación\n'
            '• Tu rutina de ejercicio\n'
            '• Tu peso de inicio',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuración de Agua', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '¿Cómo vas a medir tu ingesta de agua?',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'bottle', label: Text('Botella')),
              ButtonSegment(value: 'glass', label: Text('Vaso')),
            ],
            selected: {_waterUnit},
            onSelectionChanged: (set) {
              setState(() {
                _waterUnit = set.first;
                _containerMl = _waterUnit == 'bottle' ? 1000 : 250;
              });
            },
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tamaño del contenedor (ml)',
              suffixText: 'ml',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: '$_containerMl')
              ..selection = TextSelection.collapsed(offset: '$_containerMl'.length),
            onChanged: (v) => _containerMl = int.tryParse(v) ?? _containerMl,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Meta diaria de agua (ml)',
              suffixText: 'ml',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: '$_dailyGoalMl')
              ..selection = TextSelection.collapsed(offset: '$_dailyGoalMl'.length),
            onChanged: (v) => _dailyGoalMl = int.tryParse(v) ?? _dailyGoalMl,
          ),
          const SizedBox(height: 16),
          Text(
            'Eso equivale a aproximadamente ${_dailyGoalMl ~/ _containerMl} ${_waterUnit == 'bottle' ? 'botellas' : 'vasos'} al día.',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan de Alimentación', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Ingresa hasta 3 opciones para cada tiempo de comida. Puedes dejar en blanco las que no uses.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mealPlanNameController,
            decoration: const InputDecoration(labelText: 'Nombre del plan'),
          ),
          const SizedBox(height: 24),
          ..._mealOptions.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mealTypeLabel(entry.key),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...entry.value.asMap().entries.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: opt.value,
                      decoration: InputDecoration(
                        labelText: 'Opción ${opt.key + 1}',
                        hintText: 'Ej: Avena con frutas',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExerciseStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan de Ejercicio', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Crea los días de tu rutina (Día 1, Día 2, ...). No dependen del día de la semana: al ir al gimnasio eliges qué día entrenaste.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _exercisePlanNameController,
            decoration: const InputDecoration(labelText: 'Nombre del plan'),
          ),
          const SizedBox(height: 24),
          ..._routineDays.asMap().entries.map((dayEntry) {
            final index = dayEntry.key;
            final day = dayEntry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text('Día ${index + 1}'),
                subtitle: day.exercises.isEmpty
                    ? const Text('Sin ejercicios')
                    : Text('${day.exercises.length} ejercicio(s)'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _routineDays.removeAt(index));
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: day.nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la rutina',
                        hintText: 'Ej: Pecho y tríceps',
                      ),
                    ),
                  ),
                  ...day.exercises.asMap().entries.map((e) {
                    return _ExerciseRow(
                      entry: e.value,
                      onDelete: () {
                        setState(() => day.exercises.removeAt(e.key));
                      },
                    );
                  }),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Agregar ejercicio'),
                    onTap: () {
                      setState(() => day.exercises.add(_ExerciseEntry()));
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _routineDays.add(_RoutineDay()));
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar día de rutina'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialDataStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos de Inicio', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Estos datos marcan el inicio de tu bitácora. Podrás actualizarlos más adelante.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso inicial',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Fecha de inicio'),
            subtitle: Text(
              '${_startDate.day}/${_startDate.month}/${_startDate.year}',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Tu plan de alimentación y ejercicio se actualiza aproximadamente cada mes. Kiolog guarda el historial completo.',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoutineDay {
  final nameController = TextEditingController();
  final List<_ExerciseEntry> exercises = [];
}

class _ExerciseEntry {
  final name = TextEditingController();
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');
  final weight = TextEditingController();
}

class _ExerciseRow extends StatelessWidget {
  final _ExerciseEntry entry;
  final VoidCallback onDelete;

  const _ExerciseRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: entry.name,
              decoration: const InputDecoration(labelText: 'Ejercicio'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.sets,
              decoration: const InputDecoration(labelText: 'Sets'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.reps,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.weight,
              decoration: const InputDecoration(
                labelText: 'Peso',
                suffixText: 'kg',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
