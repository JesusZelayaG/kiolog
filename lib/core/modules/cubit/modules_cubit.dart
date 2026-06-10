// lib/core/modules/cubit/modules_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../dao/user_modules_dao.dart';
import '../../domain/app_module.dart';
import 'modules_state.dart';

class ModulesCubit extends Cubit<ModulesState> {
  final UserModulesDao _dao;

  ModulesCubit(this._dao) : super(const ModulesState());

  Future<void> loadModules() async {
    final raw = await _dao.getAllModuleStatuses();
    final statuses = {
      for (final m in AppModule.values) m: raw[m.key] ?? true,
    };
    emit(state.copyWith(statuses: statuses));
  }

  Future<void> setModuleEnabled(AppModule module, bool enabled) async {
    await _dao.setModuleEnabled(module.key, enabled);
    final updated = Map<AppModule, bool>.from(state.statuses)
      ..[module] = enabled;
    emit(state.copyWith(statuses: updated));
  }
}
