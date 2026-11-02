import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
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
    on<NutritionPlanDeleted>(_onPlanDeleted);
    on<NutritionPlanCreated>(_onPlanCreated);
    on<NutritionOptionAdded>(_onOptionAdded);
    on<NutritionProgressPlanSelected>(_onProgressPlanSelected);
  }

  Future<void> _onLoaded(
      NutritionLoaded event, Emitter<NutritionState> emit) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final logs = await _repository.getDailyLogs(event.date);
      final plans = await _repository.getAllPlans();
      final options = <String, List<MealPlanOption>>{};
      List<OptionFrequencyStat> frequencies = [];

      if (plan != null) {
        final allOpts = await _repository.getAllPlanOptions(plan.id);
        for (final opt in allOpts) {
          options.putIfAbsent(opt.mealType, () => []).add(opt);
        }
        frequencies = await _repository.getOptionFrequency(plan.id);
      }

      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);

      emit(state.copyWith(
        status: NutritionStatus.success,
        activePlan: plan,
        allPlans: plans,
        dailyLogs: logs,
        planOptions: options,
        weeklyAdherence: adherence,
        optionFrequencies: frequencies,
        error: null,
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
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      final frequencies = state.activePlan != null
          ? await _repository.getOptionFrequency(state.activePlan!.id)
          : <OptionFrequencyStat>[];
      emit(state.copyWith(
          dailyLogs: logs,
          weeklyAdherence: adherence,
          optionFrequencies: frequencies));
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
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      final frequencies = state.activePlan != null
          ? await _repository.getOptionFrequency(state.activePlan!.id)
          : <OptionFrequencyStat>[];
      emit(state.copyWith(
          dailyLogs: logs,
          weeklyAdherence: adherence,
          optionFrequencies: frequencies));
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
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      emit(state.copyWith(dailyLogs: logs, weeklyAdherence: adherence));
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
      final options = <String, List<MealPlanOption>>{};
      List<OptionFrequencyStat> frequencies = [];
      if (plan != null) {
        final allOpts = await _repository.getAllPlanOptions(plan.id);
        for (final opt in allOpts) {
          options.putIfAbsent(opt.mealType, () => []).add(opt);
        }
        frequencies = await _repository.getOptionFrequency(plan.id);
      }
      emit(state.copyWith(
        activePlan: plan,
        allPlans: plans,
        planOptions: options,
        optionFrequencies: frequencies,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanDeleted(
    NutritionPlanDeleted event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.deletePlan(event.planId);
      add(NutritionLoaded(date: DateTime.now()));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanCreated(
    NutritionPlanCreated event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.createPlan(event.name, dailyMealGoal: event.dailyMealGoal);
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
      final opts =
          await _repository.getPlanOptions(event.planId, event.mealType);
      final updated = Map<String, List<MealPlanOption>>.from(state.planOptions);
      updated[event.mealType] = opts;
      emit(state.copyWith(planOptions: updated));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onProgressPlanSelected(
    NutritionProgressPlanSelected event,
    Emitter<NutritionState> emit,
  ) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final frequencies = await _repository.getOptionFrequency(event.planId);
      final isActive = state.activePlan?.id == event.planId;
      final adherence = isActive
          ? await _repository.getWeeklyAdherence(weeksBack: 8)
          : state.weeklyAdherence;
      emit(state.copyWith(
        status: NutritionStatus.success,
        viewingPlanId: event.planId,
        optionFrequencies: frequencies,
        weeklyAdherence: adherence,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }
}
