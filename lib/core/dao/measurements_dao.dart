import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/measurements_tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [WeightLogs, Measurements])
class MeasurementsDao extends DatabaseAccessor<AppDatabase>
    with _$MeasurementsDaoMixin {
  MeasurementsDao(super.db);
}
