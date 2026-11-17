/// Trofeos de Recompensas: se ganan con meses cumplidos.
library;

/// Mes a partir del cual se cuenta un mes "cumplido".
const trophyThreshold = 70;

class Trophy {
  const Trophy(this.key, this.name, this.months);

  final String key;
  final String name;

  /// Meses cumplidos a más de [trophyThreshold] % que hacen falta.
  final int months;
}

const trophyCatalog = <Trophy>[
  Trophy('trophy_month_1', 'Trofeo de bronce: primer mes', 1),
  Trophy('trophy_month_3', 'Trofeo de plata: 3 meses', 3),
  Trophy('trophy_month_6', 'Trofeo de oro: 6 meses', 6),
  Trophy('trophy_year_1', 'Copa: 1 año', 12),
  Trophy('trophy_year_2', 'Medalla: 2 años', 24),
  Trophy('trophy_year_3', 'Medalla: 3 años', 36),
  Trophy('trophy_year_4', 'Medalla: 4 años', 48),
  Trophy('trophy_year_5', 'Medalla: 5 años', 60),
];

Trophy trophyByKey(String key) => trophyCatalog.firstWhere((t) => t.key == key);
