import 'package:equatable/equatable.dart';

class PlanComplianceStat extends Equatable {
  final int planId;
  final String planName;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final int totalSessions;
  final int weeksActive;
  final double weeklyAvg;
  final int compliancePercent;

  const PlanComplianceStat({
    required this.planId,
    required this.planName,
    required this.periodStart,
    this.periodEnd,
    required this.totalSessions,
    required this.weeksActive,
    required this.weeklyAvg,
    required this.compliancePercent,
  });

  @override
  List<Object?> get props => [
        planId,
        planName,
        periodStart,
        periodEnd,
        totalSessions,
        weeksActive,
        weeklyAvg,
        compliancePercent,
      ];
}
