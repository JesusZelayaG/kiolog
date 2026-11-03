import 'catalog.dart';
import 'unlocks.dart';

/// Lo que el usuario eligió: una pieza por espacio y los objetos del cuarto
/// que apagó. Lo que no eligió usa lo de inicio.
class Outfit {
  const Outfit({this.chosen = const {}, this.hiddenExtras = const {}});

  final Map<RewardSlot, String?> chosen;
  final Set<String> hiddenExtras;

  static const _starter = {
    RewardSlot.top: 'top_tshirt',
    RewardSlot.bottom: 'bottom_shorts',
    RewardSlot.shoes: 'shoes_basic',
    RewardSlot.bed: 'house_bed_basic',
  };

  /// Alfombra y póster aparecen solos al ganarse, hasta que se elija otro.
  static const _showWhenEarned = {RewardSlot.rug, RewardSlot.poster};

  /// La pieza que se ve en [slot]; vuelve a la de inicio si la elegida ya no
  /// está desbloqueada (por ejemplo, tras restaurar un respaldo anterior).
  String? wearing(RewardSlot slot, RewardProgress progress) {
    if (chosen.containsKey(slot)) {
      final key = chosen[slot];
      if (key == null) return null;
      if (progress.isUnlocked(itemByKey(key))) return key;
    }
    if (_showWhenEarned.contains(slot)) {
      return rewardCatalog
          .where((i) => i.slot == slot && progress.isUnlocked(i))
          .firstOrNull
          ?.key;
    }
    return _starter[slot];
  }

  /// Los nombres de todas las piezas visibles del modelo.
  Set<String> visibleParts(RewardProgress progress) {
    final trophies = trophyCatalog.where(progress.isUnlocked).map((t) => t.key);
    return {
      ...avatarBase,
      ...roomBase,
      for (final slot in RewardSlot.values)
        if (slot != RewardSlot.extra)
          if (wearing(slot, progress) case final key?) key,
      for (final item in rewardCatalog)
        if (item.slot == RewardSlot.extra &&
            progress.isUnlocked(item) &&
            !hiddenExtras.contains(item.key))
          item.key,
      if (trophies.isNotEmpty) trophyShelf,
      ...trophies,
    };
  }
}
