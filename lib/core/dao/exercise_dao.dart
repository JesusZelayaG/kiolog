import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);
}
