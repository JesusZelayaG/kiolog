import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/dao/user_modules_dao.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';

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
  final int _totalSteps = 6;

  final Set<AppModule> _activeModules = Set.from(AppModule.values);

  // Step 2: Water config
  String _waterUnit = 'bottle';
  int _containerMl = 1000;
  int _dailyGoalMl = 3000;
  late final _containerMlController =
      TextEditingController(text: '$_containerMl');
  late final _dailyGoalMlController =
      TextEditingController(text: '$_dailyGoalMl');

  // Step 3: Nutrition
  final _mealPlanNameController = TextEditingController(text: 'Mi Plan');
  final List<_MealTime> _mealTimes = [_MealTime()];

  // Step 4: Exercise — días de rutina numerados (Día 1, Día 2, ...)
  final _exercisePlanNameController = TextEditingController(text: 'Mi Rutina');
  final List<_RoutineDay> _routineDays = [];
  String _weightUnit = 'kg';

  // Step 5: Initial data
  final _weightController = TextEditingController();
  DateTime _startDate = DateTime.now();


  @override
  void dispose() {
    _pageController.dispose();
    _containerMlController.dispose();
    _dailyGoalMlController.dispose();
    _mealPlanNameController.dispose();
    _exercisePlanNameController.dispose();
    _weightController.dispose();
    for (final mt in _mealTimes) {
      mt.nameController.dispose();
      for (final c in mt.options) {
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

  bool _isStepEnabled(int stepIndex) {
    switch (stepIndex) {
      case 2:
        return _activeModules.contains(AppModule.water);
      case 3:
        return _activeModules.contains(AppModule.nutrition);
      case 4:
        return _activeModules.contains(AppModule.exercise);
      default:
        return true;
    }
  }

  int get _totalActiveSteps => 3 + _activeModules.length;

  int get _currentActiveStep {
    int count = 0;
    for (int i = 0; i <= _currentStep; i++) {
      if (_isStepEnabled(i)) count++;
    }
    return count;
  }

  bool get _canProceed =>
      _currentStep != 1 || _activeModules.isNotEmpty;

  void _nextStep() {
    var next = _currentStep + 1;
    while (next < _totalSteps && !_isStepEnabled(next)) {
      next++;
    }
    if (next < _totalSteps) {
      setState(() => _currentStep = next);
      _pageController.jumpToPage(next);
    }
  }

  void _prevStep() {
    var prev = _currentStep - 1;
    while (prev >= 0 && !_isStepEnabled(prev)) {
      prev--;
    }
    if (prev >= 0) {
      setState(() => _currentStep = prev);
      _pageController.jumpToPage(prev);
    }
  }

  Future<void> _finish() async {
    // Save water config (only if active)
    if (_activeModules.contains(AppModule.water)) {
      await getIt<WaterRepository>().saveConfig(
        unitType: _waterUnit,
        containerMl: _containerMl,
        dailyGoalMl: _dailyGoalMl,
      );
    }

    // Save nutrition plan (only if active)
    if (_activeModules.contains(AppModule.nutrition)) {
      final nutritionRepo = getIt<NutritionRepository>();
      final planId = await nutritionRepo.createPlan(
        _mealPlanNameController.text,
        dailyMealGoal: _mealTimes.length,
      );
      for (final mealTime in _mealTimes) {
        final typeName = mealTime.nameController.text.trim();
        if (typeName.isEmpty) continue;
        for (int i = 0; i < mealTime.options.length; i++) {
          final text = mealTime.options[i].text.trim();
          if (text.isNotEmpty) {
            await nutritionRepo.addPlanOption(
              planId: planId,
              mealType: typeName,
              optionNumber: i + 1,
              description: text,
            );
          }
        }
      }
    }

    // Save exercise plan (only if active)
    if (_activeModules.contains(AppModule.exercise)) {
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
    }

    // Save initial weight (unconditional)
    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      await getIt<ProgressRepository>().addWeightLog(_startDate, weight);
    }

    // Seed module statuses BEFORE marking onboarding complete
    await getIt<UserModulesDao>().seedModules({
      AppModule.water.key: _activeModules.contains(AppModule.water),
      AppModule.nutrition.key: _activeModules.contains(AppModule.nutrition),
      AppModule.exercise.key: _activeModules.contains(AppModule.exercise),
    });
    await getIt<ModulesCubit>().loadModules();

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
            SizedBox(
              height: 52,
              child: _currentStep > 0
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new),
                          onPressed: _prevStep,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(theme),
                  _buildModuleSelectionStep(theme),
                  _buildWaterStep(theme),
                  _buildNutritionStep(theme),
                  _buildExerciseStep(theme),
                  _buildInitialDataStep(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        onPressed: _canProceed
            ? (_currentStep == _totalSteps - 1 ? _finish : _nextStep)
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentStep == _totalSteps - 1 ? 'Finalizar' : 'Siguiente'),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
  Widget _buildDotsIndicator(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalActiveSteps, (i) {
        final isActive = i == _currentActiveStep - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildNavFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton(theme),
          const SizedBox(height: 8),
          _buildDotsIndicator(theme.colorScheme),
        ],
      ),
    );
  }

  Widget _buildModuleSelectionStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué quieres registrar?',
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Puedes cambiar esto más adelante en Ajustes.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _buildModuleToggle(
            theme,
            icon: Icons.water_drop_outlined,
            title: 'Hidratación',
            subtitle: 'Meta diaria de agua',
            module: AppModule.water,
          ),
          const Divider(),
          _buildModuleToggle(
            theme,
            icon: Icons.restaurant_outlined,
            title: 'Nutrición',
            subtitle: 'Plan de comidas',
            module: AppModule.nutrition,
          ),
          const Divider(),
          _buildModuleToggle(
            theme,
            icon: Icons.fitness_center_outlined,
            title: 'Ejercicio',
            subtitle: 'Rutinas y series',
            module: AppModule.exercise,
          ),
          const SizedBox(height: 16),
          Text(
            'Al menos un módulo debe estar activo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _buildNavFooter(theme),
        ],
      ),
    );
  }

  Widget _buildModuleToggle(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required AppModule module,
  }) {
    final isEnabled = _activeModules.contains(module);
    final isLast = _activeModules.length == 1 && isEnabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEnabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isEnabled
                        ? null
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: isEnabled ? 1.0 : 0.4),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: isLast
                ? null
                : (val) => setState(() {
                      if (val) {
                        _activeModules.add(module);
                      } else {
                        _activeModules.remove(module);
                      }
                    }),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    Widget infoRow(IconData icon, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenida',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
            ),
            child: Icon(
              Icons.favorite,
              size: 40,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bienvenido a Kiolog',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vamos a configurar tu bitácora de salud personal. '
            'Este proceso solo toma unos minutos.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NECESITAMOS QUE NOS CUENTES:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                infoRow(Icons.water_drop_outlined, 'Cómo medirás tu agua'),
                infoRow(Icons.restaurant_outlined, 'Tu plan de alimentación'),
                infoRow(Icons.fitness_center_outlined, 'Tu rutina de ejercicio'),
                infoRow(Icons.monitor_weight_outlined, 'Tu peso de inicio'),
              ],
            ),
          ),
          _buildNavFooter(theme),
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
          Text('Configuración de Agua', style: theme.textTheme.headlineMedium),
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
                _containerMlController.text = '$_containerMl';
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
            controller: _containerMlController,
            onChanged: (v) => _containerMl = int.tryParse(v) ?? _containerMl,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Meta diaria de agua (ml)',
              suffixText: 'ml',
            ),
            keyboardType: TextInputType.number,
            controller: _dailyGoalMlController,
            onChanged: (v) => _dailyGoalMl = int.tryParse(v) ?? _dailyGoalMl,
          ),
          const SizedBox(height: 16),
          Text(
            'Eso equivale a aproximadamente ${_dailyGoalMl ~/ _containerMl} ${_waterUnit == 'bottle' ? 'botellas' : 'vasos'} al día.',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
          _buildNavFooter(theme),
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
          Text('Plan de Alimentación', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Define tus tiempos de comida y las opciones para cada uno.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mealPlanNameController,
            decoration: const InputDecoration(labelText: 'Nombre del plan'),
          ),
          const SizedBox(height: 24),
          ..._mealTimes.asMap().entries.map((e) {
            final index = e.key;
            final mt = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Text(
                          'Tiempo ${index + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: mt.nameController,
                            decoration: const InputDecoration(
                              hintText: 'Ej: Desayuno',
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_mealTimes.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            onPressed: () {
                              setState(() {
                                mt.nameController.dispose();
                                for (final c in mt.options) {
                                  c.dispose();
                                }
                                _mealTimes.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ...mt.options.asMap().entries.map((oe) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: oe.value,
                                    decoration: InputDecoration(
                                      labelText: 'Opción ${oe.key + 1}',
                                      hintText: 'Ej: Avena con frutas',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (mt.options.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        oe.value.dispose();
                                        mt.options.removeAt(oe.key);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() =>
                                  mt.options.add(TextEditingController()));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar opción'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _mealTimes.add(_MealTime()));
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar tiempo de comida'),
          ),
          const SizedBox(height: 8),
          Text(
            'Meta diaria automática: ${_mealTimes.length} ${_mealTimes.length == 1 ? 'comida' : 'comidas'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _buildNavFooter(theme),
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
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'kg', label: Text('kg')),
              ButtonSegment(value: 'lbs', label: Text('lbs')),
            ],
            selected: {_weightUnit},
            onSelectionChanged: (set) =>
                setState(() => _weightUnit = set.first),
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
                    setState(() {
                      final removed = _routineDays.removeAt(index);
                      removed.nameController.dispose();
                      for (final e in removed.exercises) {
                        e.name.dispose();
                        e.sets.dispose();
                        e.reps.dispose();
                        e.weight.dispose();
                      }
                    });
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
                      weightUnit: _weightUnit,
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
          _buildNavFooter(theme),
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
          _buildNavFooter(theme),
        ],
      ),
    );
  }
}

class _MealTime {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
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
  final String weightUnit;
  final VoidCallback onDelete;

  const _ExerciseRow({
    required this.entry,
    required this.weightUnit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.name,
                  decoration: const InputDecoration(
                    labelText: 'Ejercicio',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.sets,
                  decoration: const InputDecoration(
                    labelText: 'Series',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: entry.reps,
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: entry.weight,
                  decoration: InputDecoration(
                    labelText: 'Peso',
                    suffixText: weightUnit,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
