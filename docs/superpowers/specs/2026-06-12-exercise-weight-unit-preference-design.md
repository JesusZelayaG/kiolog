# Exercise Weight Unit Global Preference

**Date:** 2026-06-12  
**Status:** Approved

## Problem

The weight unit (kg/lbs) shown in all exercise screens was hardcoded to "kg". Users who train in lbs had no way to change the display. The previous per-plan `weightUnit` DB column (added in migration v9) stores what unit was used at plan creation time but doesn't provide a live global toggle.

## Goal

A single global preference — stored in SharedPreferences — that controls the weight unit label across all exercise screens. Default: **lbs**. User can toggle it from within the exercise section.

## Architecture

### Layer 1 — `ExerciseWeightUnitService`

Thin wrapper over `SharedPreferences`.

- **File:** `lib/features/exercise/data/services/exercise_weight_unit_service.dart`
- **Key:** `exercise_weight_unit`
- **Default:** `lbs`
- **Methods:** `Future<String> getUnit()`, `Future<void> setUnit(String unit)`

### Layer 2 — `ExerciseWeightUnitCubit`

Simple Cubit; state is just `String` (the unit).

- **File:** `lib/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart`
- **State:** `String` (emits `'kg'` or `'lbs'`)
- **Methods:**
  - `init()` — loads from service, emits stored value (or default `lbs`)
  - `setUnit(String)` — saves via service, emits new value

### Layer 3 — DI + UI

- `shared_preferences` added to `pubspec.yaml`
- `ExerciseWeightUnitService` registered as lazy singleton in `injection.dart` (requires async `SharedPreferences.getInstance()` — use `registerSingletonAsync` or init before registration)
- `ExerciseWeightUnitCubit` provided via `BlocProvider` in the exercise route, alongside the existing `ExerciseBloc`
- Toggle: small `SegmentedButton<String>` inside the exercise page (top of the rutina section)

## Weight Display Migration

All screens that previously hardcoded `'kg'` now use `context.watch<ExerciseWeightUnitCubit>().state` (or pass `weightUnit` as a parameter):

| Location | Change |
|---|---|
| `exercise_page._buildItemRow` | already uses `state.planWeightUnit` → switch to cubit |
| `exercise_page._showExerciseDialog` | already uses `state.planWeightUnit` → switch to cubit |
| `exercise_page._buildIndependentItem` | same |
| `exercise_page._showIndependentExerciseDialog` | same |
| `exercise_session_page._buildItemTile` | already uses `state.planWeightUnit` → switch to cubit |
| `exercise_session_page._buildSetRow` (historical display) | same |
| `exercise_session_page` table header `'Peso ${unit}'` | same |

`state.planWeightUnit` getter on `ExerciseState` (added in the previous session) can be removed after the cubit is wired — or kept as fallback.

## Toggle UI

A `SegmentedButton<String>` with two segments (`kg` / `lbs`) placed at the top of `_buildRutinaSection`, before the routine day cards. It reads and writes via `ExerciseWeightUnitCubit`.

## No Conversion

The raw number stored in the DB is displayed as-is with the selected unit label. No arithmetic conversion between kg and lbs happens. The DB column `weightKg` is a naming legacy — the actual unit depends on what the user typed at entry time.

## Out of Scope

- Converting historical values between units
- Per-plan override of the global setting
- Showing unit preference anywhere outside the exercise module
