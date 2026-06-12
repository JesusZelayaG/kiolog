# Detailed Report PDF Design

## Goal

Expand the existing health report to include a detailed nutrition section (active meal plan + meal frequency with horizontal bar charts) and a detailed exercise section (active exercise plan + weekly compliance chart + cardio/free exercise counts), exported as a shareable PDF.

## Architecture

Sub-models + PDF service pattern. `ReportData` gains two nullable nested objects (`NutritionReportData`, `ExerciseReportData`). PDF generation logic moves out of `report_page.dart` into a standalone `PdfReportService`. The UI layer calls `PdfReportService.generate(data)` and delegates sharing to `share_plus`.

## Tech Stack

- `pdf: ^3.10.7` — PDF generation with `pw.Stack` + `pw.Container` for horizontal bar charts (no additional charting library needed)
- `share_plus: ^12.0.2` — sharing the generated file
- `path_provider` — temp directory for the PDF file
- Drift DAOs — `NutritionDao`, `ExerciseDao`, existing `getOptionFrequenciesForPlan`, `getCompletedSessionsInPeriod`

---

## Data Models

### New file: `lib/features/reports/domain/repositories/report_repository.dart` (expanded)

**`MealFrequencyEntry`**
```dart
class MealFrequencyEntry {
  final String mealType;        // desayuno, almuerzo, cena, snack
  final String description;     // option description
  final int count;              // times logged in the period
}
```

**`WeeklyComplianceEntry`**
```dart
class WeeklyComplianceEntry {
  final String weekLabel;   // "Sem 1", "Sem 2", ...
  final int daysDone;       // unique routine days completed that week
  final int daysGoal;       // weeklyRoutineDaysGoal from config (default 4)
}
```

**`NutritionReportData`**
```dart
class NutritionReportData {
  final String? planName;
  final List<MealFrequencyEntry> mealFrequencies;
  // grouped by mealType for rendering; ordered by count desc within each group
}
```

**`ExerciseReportData`**
```dart
class ExerciseReportData {
  final String? planName;
  final List<WeeklyComplianceEntry> weeklyCompliance;
  final int totalRoutineSessions;
  final int cardioSessionsCount;
  final int freeExerciseCount;
}
```

**`ReportData` additions** (appended to existing fields):
```dart
final NutritionReportData? nutritionDetail;
final ExerciseReportData? exerciseDetail;
```

Both nullable — if no plan or no data exists in the range, the PDF section is omitted.

---

## Repository Layer

### `ReportRepositoryImpl.generateReport()` expansion

The existing day-loop stays for water/sleep/nutrition compliance counts. After the loop, new queries run in parallel via `Future.wait`:

**Nutrition detail:**
1. `nutritionDao.getActiveMealPlan()` → `planName`
2. If plan exists: `nutritionDao.getLogsInRange(start, end)` → `DailyMealLog` list (respects the user's selected date range, not the plan's full period)
3. `nutritionDao.getAllPlanOptions(planId)` → join with logs to compute per-option `count`
4. Group by `mealType`, sort each group by `count` descending, drop entries with `count == 0`

**Exercise detail:**
1. `exerciseDao.getActiveExercisePlan()` → `planName`, get routineIds via `getRoutinesForPlan`
2. `exerciseDao.getExerciseConfig()` → `daysGoal` (default 4)
3. `exerciseDao.getCompletedSessionsInPeriod(routineIds, start, end)` → sessions grouped by ISO week → `weeklyCompliance` list; week labels "Sem 1", "Sem 2"... indexed from the Monday on or before `start`
4. Cardio: **new DAO method** `getCardioLogsInRange(start, end)` → count → `cardioSessionsCount`
5. Free exercise: **new DAO method** `getSessionsInRange(start, end)` → filter `routineId == null && gymLeftAt != null` → count → `freeExerciseCount`
6. `totalRoutineSessions`: unique calendar days in step 3 results (same counting logic as compliance formula)

Week labels: "Sem 1", "Sem 2", … indexed from the first week of the selected range (not the plan start).

---

## PDF Service

### New file: `lib/features/reports/data/pdf_report_service.dart`

Static class with a single public method:

```dart
class PdfReportService {
  static Future<File> generate(ReportData data) async { ... }
}
```

**PDF layout — flujo continuo (single multi-page document):**

```
HEADER
  "Kiolog — Reporte de Salud"   bold 20pt
  "12 may – 11 jun 2026"        12pt gray

RESUMEN
  Section heading: "RESUMEN"
  Horizontal bar row per metric (Agua, Nutrición, Ejercicio, Sueño if available)
    label | bar (proportional 0–100%) | percentage + "X/Y días"

NUTRICIÓN  (omitted if nutritionDetail == null)
  Section heading: "NUTRICIÓN"
  Sub-heading: "Plan: <planName>" or "Sin plan activo"
  For each mealType group (only groups with count > 0):
    mealType label (bold, small caps)
    For each MealFrequencyEntry, sorted by count desc:
      description | bar (proportional to max count in group) | count×

EJERCICIO  (omitted if exerciseDetail == null)
  Section heading: "EJERCICIO"
  Sub-heading: "Plan: <planName>" or "Sin plan activo"
  "Cumplimiento semanal" label
  For each WeeklyComplianceEntry:
    weekLabel | bar (proportional to daysGoal) | "daysDone/daysGoal días"
  Summary row: "Rutina: X sesiones · Cardio: Y · Ejercicio libre: Z"

MEDIDAS  (omitted if weightLogs.isEmpty && latestMeasurement == null)
  Section heading: "MEDIDAS"
  Weight table: date | weight kg (one row per WeightLog)
  Latest measurement row if available

FOOTER
  "Generado por Kiolog · <date>"   small gray
```

**Bar rendering:** Each bar is a `pw.Stack` with a full-width gray background container and a colored foreground container at `width = maxWidth * (value / maxValue)`. Bars cap at the container width via `.clamp(0.0, 1.0)`.

**Color palette in PDF:**
- Resumen bars: `PdfColor.fromHex('22C55E')` (green)
- Nutrition bars: `PdfColor.fromHex('4EDEA3')` (secondary teal)
- Exercise bars: `PdfColor.fromHex('AFC7FF')` (tertiary blue)
- Bar track: `PdfColor.fromHex('2D3449')` (surface container)
- Background: white (PDF standard, readable when printed)
- Text: `PdfColors.black` / `PdfColor.fromHex('374151')` for body

**Page format:** `PdfPageFormat.a4`, margins 32pt all sides.

**File path:** `${tempDir}/kiolog_reporte_<yyyyMMdd>.pdf` — timestamped to avoid stale cached files.

---

## UI Changes

### `report_page.dart`

- Remove `_exportPdf()` method and `_pdfMetric()` helper (replaced by `PdfReportService`)
- Add nutrition detail section to `_buildReportContent` preview (mirrors PDF: meal frequency bars per group)
- Add exercise detail section to `_buildReportContent` preview (weekly compliance bars + summary row)
- "Exportar PDF" button calls `PdfReportService.generate(data)` then `Share.shareXFiles`
- Preview uses the app's existing `VitalityProgressBar` widget for the bars

The in-app preview and the PDF show the same data — the preview uses Flutter widgets, the PDF uses `pw` equivalents.

---

## File Map

| Action | File |
|--------|------|
| Modify | `lib/features/reports/domain/repositories/report_repository.dart` — add 4 new model classes + 2 fields to `ReportData` |
| Modify | `lib/core/dao/exercise_dao.dart` — add `getCardioLogsInRange` and `getSessionsInRange` methods |
| Modify | `lib/features/reports/data/repositories/report_repository_impl.dart` — add nutrition + exercise detail queries |
| Create | `lib/features/reports/data/pdf_report_service.dart` — standalone PDF generator |
| Modify | `lib/features/reports/presentation/pages/report_page.dart` — add detail preview sections, replace `_exportPdf` with service call |

No new BLoC events or states needed — `ReportData` is already the single payload emitted on `ReportGenerated`.

---

## Error Handling

- If `getActiveMealPlan()` or `getActiveExercisePlan()` returns null: `nutritionDetail`/`exerciseDetail` are null → sections omitted silently
- If the date range contains no sessions/logs for a section: empty lists → section heading still shows, bars section shows "Sin datos en este período"
- PDF generation failure: caught in `report_page.dart`, shown as `ScaffoldMessenger` snackbar

## Testing

- Unit test `NutritionReportData` grouping logic (group by mealType, sort by count desc, drop zeros)
- Unit test `ExerciseReportData` weekly grouping (correct week boundaries, correct label indexing)
- Unit test `ReportRepositoryImpl` with in-memory Drift DB: verify nutrition + exercise detail fields populate correctly for a seeded range
- No widget tests for `PdfReportService` — PDF output is not widget-testable; verify via manual share on device
