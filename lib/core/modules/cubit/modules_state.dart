// lib/core/modules/cubit/modules_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/app_module.dart';

class ModulesState extends Equatable {
  final Map<AppModule, bool> statuses;

  const ModulesState({this.statuses = const {}});

  bool isEnabled(AppModule module) => statuses[module] ?? true;

  ModulesState copyWith({Map<AppModule, bool>? statuses}) =>
      ModulesState(statuses: statuses ?? this.statuses);

  @override
  List<Object?> get props => [statuses];
}
