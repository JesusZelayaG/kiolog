# Home Page Vitality Dark Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar `home_page.dart` con hero header (% meta diaria + barra), grid mixto (2 cards wide + 2 compact en row), y background images en cada tarjeta.

**Architecture:** Un solo archivo modificado (`home_page.dart`). Se extrae `calcOverallProgress` como función top-level pública para testabilidad. `_ModuleCard` se elimina y se reemplaza por `_WideModuleCard` y `_CompactModuleCard`. El BLoC no cambia.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test

---

### Task 1: Escribir tests de `calcOverallProgress` (TDD — failing first)

**Files:**
- Create: `test/unit/home_progress_test.dart`

- [ ] **Step 1: Crear el archivo de test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/home/presentation/bloc/home_state.dart';
import 'package:kiolog/features/home/presentation/pages/home_page.dart';

void main() {
  group('calcOverallProgress', () {
    test('returns 0.0 cuando todos los módulos están en cero', () {
      const s = HomeState();
      expect(calcOverallProgress(s), 0.0);
    });

    test('returns 1.0 cuando todos los módulos están completos', () {
      const s = HomeState(
        dailyWaterTotalMl: 3000,
        dailyWaterGoalMl: 3000,
        sleepHours: 8.0,
        mealsLogged: 4,
        totalMeals: 4,
        exerciseRoutineDone: true,
      );
      expect(calcOverallProgress(s), 1.0);
    });

    test('returns promedio correcto con valores parciales', () {
      // agua: 0.5, sueño: 0.5, nutrición: 0.5, ejercicio: 0.0 → 0.375
      const s = HomeState(
        dailyWaterTotalMl: 1500,
        dailyWaterGoalMl: 3000,
        sleepHours: 4.0,
        mealsLogged: 2,
        totalMeals: 4,
      );
      expect(calcOverallProgress(s), closeTo(0.375, 0.001));
    });

    test('hasGymSession aporta 0.5 al progreso de ejercicio', () {
      // agua: 0, sueño: 0, nutrición: 0, ejercicio: 0.5 → 0.125
      const s = HomeState(hasGymSession: true);
      expect(calcOverallProgress(s), closeTo(0.125, 0.001));
    });
  });
}
```

- [ ] **Step 2: Correr tests para verificar que fallan**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/home_progress_test.dart 2>&1
```

Esperado: error de compilación — `calcOverallProgress` no existe aún.

---

### Task 2: Extraer `calcOverallProgress` + reescribir header

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Agregar `calcOverallProgress` como función top-level pública, antes de la clase `HomePage`**

Insertar justo antes de `class HomePage`:

```dart
double calcOverallProgress(HomeState s) {
  final values = [
    s.waterProgress,
    s.sleepHours != null ? (s.sleepHours! / 8).clamp(0.0, 1.0) : 0.0,
    s.totalMeals > 0 ? s.mealsLogged / s.totalMeals : 0.0,
    s.exerciseRoutineDone ? 1.0 : (s.hasGymSession ? 0.5 : 0.0),
  ];
  return values.reduce((a, b) => a + b) / values.length;
}
```

- [ ] **Step 2: Correr tests para verificar que pasan**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/home_progress_test.dart 2>&1
```

Esperado: 4/4 tests pasan.

- [ ] **Step 3: Eliminar `_greeting`, `_dateLabel`, `_timeGreeting` de `_HomeViewState`**

Reemplazar el bloque:

```dart
class _HomeViewState extends State<_HomeView> {
  late final String _greeting;
  late final String _dateLabel;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _greeting = _timeGreeting(now.hour);
    _dateLabel = DateFormat('EEEE, d MMM', 'es').format(now);
  }

  String _timeGreeting(int hour) {
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }
```

Por:

```dart
class _HomeViewState extends State<_HomeView> {
```

Y eliminar el import de `intl` si ya no se usa:
```dart
import 'package:intl/intl.dart';  // ← eliminar esta línea
```

- [ ] **Step 4: Reemplazar el `SliverToBoxAdapter` del header**

Reemplazar:

```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: theme.textTheme.displayLarge,
        ),
        const SizedBox(height: 4),
        Text(
          _dateLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
      ],
    ),
  ),
),
```

Por:

```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (context) {
          final overall = calcOverallProgress(state);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIENVENIDO DE NUEVO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Resumen del día',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(overall * 100).round()}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        'META DIARIA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              VitalityProgressBar(value: overall, color: cs.primary),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    ),
  ),
),
```

- [ ] **Step 5: Verificar que compila**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/home/presentation/pages/home_page.dart 2>&1 | tail -5
```

Esperado: 0 errores (puede haber warnings de `_ModuleCard` aún en uso).

---

### Task 3: Implementar `_WideModuleCard`

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Agregar `_WideModuleCard` al final del archivo (antes del último `}`)**

```dart
class _WideModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String bgImage;
  final bool showAction;
  final VoidCallback onTap;

  const _WideModuleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgImage,
    required this.onTap,
    this.showAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bgImage, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.50)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ModuleIconBadge(icon: icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showAction)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: onTap,
                        child: const Text('VER AHORA'),
                      )
                    else
                      Icon(
                        Icons.chevron_right,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/home/presentation/pages/home_page.dart 2>&1 | tail -5
```

Esperado: 0 errores.

---

### Task 4: Implementar `_CompactModuleCard`

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Agregar `_CompactModuleCard` al final del archivo, después de `_WideModuleCard`**

```dart
class _CompactModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String bgImage;
  final VoidCallback onTap;

  const _CompactModuleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bgImage, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.55)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModuleIconBadge(icon: icon, color: color, size: 32),
                    const Spacer(),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/home/presentation/pages/home_page.dart 2>&1 | tail -5
```

Esperado: 0 errores.

---

### Task 5: Actualizar body layout + eliminar `_ModuleCard` + commit

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Reemplazar el `SliverPadding` body completo**

Reemplazar:

```dart
SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  sliver: SliverList(
    delegate: SliverChildListDelegate([
      _ModuleCard(
        icon: Icons.water_drop,
        label: 'Agua',
        color: cs.tertiary,
        progress: state.waterProgress,
        subtitle:
            '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
        onTap: () => context.push('/water'),
      ),
      const SizedBox(height: 16),
      _ModuleCard(
        icon: Icons.nightlight_round,
        label: 'Sueño',
        color: const Color(0xFFAFC7FF),
        progress: state.sleepHours != null
            ? (state.sleepHours! / 8).clamp(0.0, 1.0)
            : 0.0,
        subtitle: state.sleepHours != null
            ? '${state.sleepHours!.toStringAsFixed(1)} h'
            : 'No registrado',
        onTap: () => context.push('/sleep'),
      ),
      const SizedBox(height: 16),
      _ModuleCard(
        icon: Icons.restaurant,
        label: 'Nutrición',
        color: cs.secondary,
        progress: state.totalMeals > 0
            ? state.mealsLogged / state.totalMeals
            : 0.0,
        subtitle:
            '${state.mealsLogged} / ${state.totalMeals} comidas',
        onTap: () => context.go('/nutrition'),
      ),
      const SizedBox(height: 16),
      _ModuleCard(
        icon: Icons.fitness_center,
        label: 'Ejercicio',
        color: cs.primary,
        progress: state.exerciseRoutineDone ? 1.0 : 0.0,
        subtitle: state.exerciseRoutineDone
            ? 'Rutina completada'
            : state.hasGymSession
                ? 'Sesión en progreso'
                : 'Pendiente',
        onTap: () => context.go('/exercise'),
      ),
      const SizedBox(height: 32),
    ]),
  ),
),
```

Por:

```dart
SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  sliver: SliverList(
    delegate: SliverChildListDelegate([
      _WideModuleCard(
        icon: Icons.water_drop,
        label: 'Agua',
        subtitle:
            '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
        color: cs.tertiary,
        bgImage: 'assets/img/water_bg.png',
        onTap: () => context.push('/water'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _CompactModuleCard(
              icon: Icons.nightlight_round,
              label: 'Sueño',
              subtitle: state.sleepHours != null
                  ? '${state.sleepHours!.toStringAsFixed(1)} h'
                  : 'Sin registro',
              color: const Color(0xFFAFC7FF),
              bgImage: 'assets/img/sleep_bg.png',
              onTap: () => context.push('/sleep'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CompactModuleCard(
              icon: Icons.restaurant,
              label: 'Nutrición',
              subtitle:
                  '${state.mealsLogged} / ${state.totalMeals} comidas',
              color: cs.secondary,
              bgImage: 'assets/img/nutrition_bg.png',
              onTap: () => context.go('/nutrition'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _WideModuleCard(
        icon: Icons.fitness_center,
        label: 'Ejercicio',
        subtitle: state.exerciseRoutineDone
            ? 'Rutina completada'
            : state.hasGymSession
                ? 'Sesión en progreso'
                : 'Pendiente',
        color: cs.primary,
        bgImage: 'assets/img/exercise_bg.png',
        showAction: true,
        onTap: () => context.go('/exercise'),
      ),
      const SizedBox(height: 32),
    ]),
  ),
),
```

- [ ] **Step 2: Eliminar la clase `_ModuleCard` completa**

Eliminar desde `class _ModuleCard extends StatelessWidget {` hasta el `}` de cierre de la clase.

- [ ] **Step 3: Correr todos los tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/home_progress_test.dart 2>&1
```

Esperado: 4/4 pasan.

- [ ] **Step 4: Verificar analyze limpio**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/home/presentation/pages/home_page.dart 2>&1 | tail -5
```

Esperado: `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /home/jesuszelaya/Documents/kiolog && git add lib/features/home/presentation/pages/home_page.dart test/unit/home_progress_test.dart && git commit -m "feat(home): Vitality Dark redesign — hero header, wide/compact cards, bg images"
```
