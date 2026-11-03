import 'package:drift/drift.dart';

/// Recompensas que el usuario se pone para un mes: se desbloquean al llegar
/// a [threshold] % del mes.
class MonthlyRewards extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Mes en formato yyyy-MM.
  TextColumn get month => text()();

  /// 25, 50, 75 o 100.
  IntColumn get threshold => integer()();
  TextColumn get title => text()();

  /// Cuándo se dio el gusto; null si todavía no.
  DateTimeColumn get redeemedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {month, threshold},
      ];
}

/// Elecciones de Recompensas: qué se viste, qué se oculta del cuarto y qué
/// desbloqueos ya se anunciaron. Claves: slot.<espacio>, hidden.<pieza>,
/// seen.<pieza>.
class RewardSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
