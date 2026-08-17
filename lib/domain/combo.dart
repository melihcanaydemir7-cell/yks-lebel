/// Visual tiers for the consecutive-correct-answer combo.
enum ComboTier { none, small, medium, onFire }

class ComboService {
  const ComboService._();

  static ComboTier tierFor(int combo) {
    if (combo >= 5) return ComboTier.onFire;
    if (combo >= 3) return ComboTier.medium;
    if (combo >= 2) return ComboTier.small;
    return ComboTier.none;
  }

  static int next({required int current, required bool isCorrect}) =>
      isCorrect ? current + 1 : 0;
}
