import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/nutrition_repository.dart';
import 'nutrition_event.dart';
import 'nutrition_state.dart';

class NutritionBloc extends Bloc<NutritionEvent, NutritionState> {
  final NutritionRepository _repository;

  NutritionBloc(this._repository) : super(const NutritionState()) {
    on<NutritionLoaded>(_onLoaded);
    on<NutritionPlanLoaded>(_onPlanLoaded);
    on<NutritionMealLogged>(_onMealLogged);
    on<NutritionOffPlanMealLogged>(_onOffPlanMealLogged);
    on<NutritionMealLogRemoved>(_onMealLogRemoved);
    on<NutritionPlanActivated>(_onPlanActivated);
    on<NutritionPlanCreated>(_onPlanCreated);
    on<NutritionOptionAdded>(_onOptionAdded);
  }

  Future<void> _onLoaded(NutritionLoaded event, Emitter<NutritionState> emit) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final logs = await _repository.getDailyLogs(event.date);
      final options = <String, List<MealPlanOption>>{};

      if (plan != null) {
        for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
          final opts = await _repository.getPlanOptions(plan.id, mealType);
          options[mealType] = opts;
        }
      }

      emit(state.copyWith(
        status: NutritionStatus.success,
        activePlan: plan,
        dailyLogs: logs,
        planOptions: options,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanLoaded(
    NutritionPlanLoaded event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      final plans = await _repository.getAllPlans();
      final active = await _repository.getActivePlan();
      emit(state.copyWith(allPlans: plans, activePlan: active));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onMealLogged(
    NutritionMealLogged event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.logMeal(
        date: event.date,
        mealType: event.mealType,
        planOptionId: event.planOptionId,
      );
      final logs = await _repository.getDailyLogs(event.date);
      emit(state.copyWith(dailyLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onMealLogRemoved(
    NutritionMealLogRemoved event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.removeMealLog(
        date: event.date,
        mealType: event.mealType,
      );
      final logs = await _repository.getDailyLogs(event.date);
      emit(state.copyWith(dailyLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onOffPlanMealLogged(
    NutritionOffPlanMealLogged event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.logOffPlanMeal(
        date: event.date,
        mealType: event.mealType,
        description: event.description,
      );
      final logs = await _repository.getDailyLogs(event.date);
      emit(state.copyWith(dailyLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
    NutritionPlanActivated event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.activatePlan(event.planId);
      final plan = await _repository.getActivePlan();
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(activePlan: plan, allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanCreated(
    NutritionPlanCreated event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.createPlan(event.name);
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onOptionAdded(
    NutritionOptionAdded event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.addPlanOption(
        planId: event.planId,
        mealType: event.mealType,
        optionNumber: event.optionNumber,
        description: event.description,
      );
      final opts = await _repository.getPlanOptions(event.planId, event.mealType);
      final updated = Map<String, List<MealPlanOption>>.from(state.planOptions);
      updated[event.mealType] = opts;
      emit(state.copyWith(planOptions: updated));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }
}
