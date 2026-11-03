/// Lo que se puede ganar en Recompensas. Cada [RewardItem.key] es el nombre
/// de una pieza en assets/models/rewards.glb.
library;

enum RewardSlot {
  top('Camisa'),
  bottom('Pantalón'),
  shoes('Zapatos'),
  head('Cabeza'),
  face('Cara'),
  wrist('Muñeca'),
  bed('Cama'),
  rug('Alfombra'),
  poster('Póster'),

  /// Muebles y objetos que pueden estar todos a la vez.
  extra('Cuarto');

  const RewardSlot(this.label);
  final String label;

  bool get isAvatar => index <= RewardSlot.wrist.index;

  /// Si se puede dejar vacío.
  bool get optional => this != top && this != bottom && this != shoes && this != bed;
}

/// Logros con un objetivo contable.
enum Goal {
  waterStreak7('7 días seguidos con la meta de agua', 7),
  cardio10('10 sesiones de cardio', 10),
  cardio20('20 sesiones de cardio', 20),
  routines10('10 días de rutina', 10),
  planMeals30('30 comidas del plan', 30),
  planMeals50('50 comidas del plan', 50),
  weights30('30 pesos registrados', 30),
  sleepStreak14('14 días seguidos registrando sueño', 14),
  fullMealsStreak15('15 días seguidos con todas las comidas del plan', 15),
  perfectDays30('30 días con comidas, agua, sueño y peso cumplidos', 30);

  const Goal(this.label, this.target);
  final String label;
  final int target;
}

sealed class Unlock {
  const Unlock();
}

class FromStart extends Unlock {
  const FromStart();
}

class AtLevel extends Unlock {
  const AtLevel(this.level);
  final int level;
}

class ByGoal extends Unlock {
  const ByGoal(this.goal);
  final Goal goal;
}

/// Meses cumplidos a más del 70 %.
class ByMonths extends Unlock {
  const ByMonths(this.months);
  final int months;
}

class RewardItem {
  const RewardItem(this.key, this.name, this.slot, this.unlock);

  final String key;
  final String name;
  final RewardSlot slot;
  final Unlock unlock;
}

/// Piezas que siempre se ven.
const avatarBase = ['avatar_body', 'avatar_face', 'avatar_hair'];
const roomBase = [
  'house_floor',
  'house_wall_back',
  'house_wall_left',
  'house_baseboard',
  'house_window',
];

/// Mes a partir del cual se cuenta un mes "cumplido".
const trophyThreshold = 70;

const rewardCatalog = <RewardItem>[
  // Avatar
  RewardItem('top_tshirt', 'Camisa verde', RewardSlot.top, FromStart()),
  RewardItem('top_tshirt_stripes', 'Camisa a rayas', RewardSlot.top, AtLevel(3)),
  RewardItem('top_tshirt_heart', 'Camisa con corazón', RewardSlot.top, AtLevel(6)),
  RewardItem('top_tank', 'Camisa sin mangas', RewardSlot.top, ByGoal(Goal.routines10)),
  RewardItem('top_hoodie', 'Sudadera', RewardSlot.top, AtLevel(9)),
  RewardItem('top_jacket', 'Chaqueta deportiva', RewardSlot.top, AtLevel(14)),
  RewardItem('bottom_shorts', 'Shorts', RewardSlot.bottom, FromStart()),
  RewardItem('bottom_joggers', 'Pants', RewardSlot.bottom, AtLevel(4)),
  RewardItem('bottom_shorts_sport', 'Shorts deportivos', RewardSlot.bottom, AtLevel(11)),
  RewardItem('shoes_basic', 'Tenis básicos', RewardSlot.shoes, FromStart()),
  RewardItem('shoes_running', 'Tenis para correr', RewardSlot.shoes, ByGoal(Goal.cardio10)),
  RewardItem('shoes_hightop', 'Tenis de bota', RewardSlot.shoes, AtLevel(8)),
  RewardItem('shoes_gold', 'Tenis dorados', RewardSlot.shoes, AtLevel(20)),
  RewardItem('acc_headband', 'Banda', RewardSlot.head, ByGoal(Goal.sleepStreak14)),
  RewardItem('acc_cap', 'Gorra', RewardSlot.head, AtLevel(7)),
  RewardItem('acc_beanie', 'Gorro', RewardSlot.head, AtLevel(12)),
  RewardItem('acc_sunglasses', 'Lentes de sol', RewardSlot.face, ByGoal(Goal.fullMealsStreak15)),
  RewardItem('acc_watch', 'Reloj', RewardSlot.wrist, ByGoal(Goal.weights30)),
  RewardItem('acc_smartband', 'Pulsera deportiva', RewardSlot.wrist, ByGoal(Goal.perfectDays30)),
  // Cuarto
  RewardItem('house_bed_basic', 'Colchón', RewardSlot.bed, FromStart()),
  RewardItem('house_bed_nice', 'Cama con cabecera', RewardSlot.bed, AtLevel(10)),
  RewardItem('house_rug', 'Alfombra rosa', RewardSlot.rug, AtLevel(2)),
  RewardItem('house_rug_blue', 'Alfombra azul', RewardSlot.rug, AtLevel(13)),
  RewardItem('house_poster_simple', 'Póster simple', RewardSlot.poster, AtLevel(2)),
  RewardItem('house_poster_mountain', 'Póster de montaña', RewardSlot.poster, AtLevel(3)),
  RewardItem('house_poster_kiolog', 'Póster KIOLOG', RewardSlot.poster, AtLevel(8)),
  RewardItem('house_poster_fruit', 'Póster de frutas', RewardSlot.poster, ByGoal(Goal.planMeals30)),
  RewardItem('house_yoga_mat', 'Tapete de yoga', RewardSlot.extra, FromStart()),
  RewardItem('house_dumbbells', 'Mancuernas', RewardSlot.extra, AtLevel(4)),
  RewardItem('house_plant', 'Planta', RewardSlot.extra, AtLevel(5)),
  RewardItem('house_lamp', 'Lámpara', RewardSlot.extra, AtLevel(6)),
  RewardItem('house_shelf', 'Repisa con libros', RewardSlot.extra, AtLevel(10)),
  RewardItem('house_bike', 'Bici fija', RewardSlot.extra, AtLevel(15)),
  RewardItem('house_water_bottle', 'Botella de agua', RewardSlot.extra, ByGoal(Goal.waterStreak7)),
  RewardItem('house_kettlebell', 'Pesa rusa', RewardSlot.extra, ByGoal(Goal.cardio20)),
  RewardItem('house_cactus', 'Cactus', RewardSlot.extra, ByGoal(Goal.planMeals50)),
];

/// Trofeos del estante: se muestran solos al ganarse.
const trophyCatalog = <RewardItem>[
  RewardItem('trophy_month_1', 'Trofeo de bronce: primer mes', RewardSlot.extra, ByMonths(1)),
  RewardItem('trophy_month_3', 'Trofeo de plata: 3 meses', RewardSlot.extra, ByMonths(3)),
  RewardItem('trophy_month_6', 'Trofeo de oro: 6 meses', RewardSlot.extra, ByMonths(6)),
  RewardItem('trophy_year_1', 'Copa: 1 año', RewardSlot.extra, ByMonths(12)),
  RewardItem('trophy_year_2', 'Medalla: 2 años', RewardSlot.extra, ByMonths(24)),
  RewardItem('trophy_year_3', 'Medalla: 3 años', RewardSlot.extra, ByMonths(36)),
  RewardItem('trophy_year_4', 'Medalla: 4 años', RewardSlot.extra, ByMonths(48)),
  RewardItem('trophy_year_5', 'Medalla: 5 años', RewardSlot.extra, ByMonths(60)),
];

const trophyShelf = 'house_trophy_shelf';

RewardItem itemByKey(String key) =>
    [...rewardCatalog, ...trophyCatalog].firstWhere((i) => i.key == key);
