import 'package:flutter_test/flutter_test.dart';
import 'package:yks_level/domain/combo.dart';
import 'package:yks_level/domain/xp.dart';

void main() {
  group('requiredXpForLevel', () {
    test('follows round(100 * level^1.25)', () {
      expect(XpService.requiredXpForLevel(1), 100);
      expect(XpService.requiredXpForLevel(2), 238);
      expect(XpService.requiredXpForLevel(10), 1778);
    });

    test('is zero at and beyond the cap', () {
      expect(XpService.requiredXpForLevel(XpService.maxLevel), 0);
      expect(XpService.requiredXpForLevel(0), 0);
    });

    test('is strictly increasing', () {
      for (var level = 1; level < 50; level++) {
        expect(
          XpService.requiredXpForLevel(level + 1),
          greaterThan(XpService.requiredXpForLevel(level)),
        );
      }
    });
  });

  group('levelForTotalXp', () {
    test('starts at level 1', () {
      expect(XpService.levelForTotalXp(0), 1);
      expect(XpService.levelForTotalXp(-50), 1);
      expect(XpService.levelForTotalXp(99), 1);
    });

    test('advances exactly at the threshold', () {
      expect(XpService.levelForTotalXp(100), 2);
      expect(XpService.levelForTotalXp(337), 2);
      expect(XpService.levelForTotalXp(338), 3);
    });

    test('never exceeds the cap', () {
      expect(XpService.levelForTotalXp(100000000), XpService.maxLevel);
    });

    test('stays consistent with the cumulative curve', () {
      for (var level = 1; level <= 30; level++) {
        final atLevel = XpService.cumulativeXpForLevel(level);
        expect(XpService.levelForTotalXp(atLevel), level);
        if (level > 1) {
          expect(XpService.levelForTotalXp(atLevel - 1), level - 1);
        }
      }
    });
  });

  group('progress within a level', () {
    test('splits total XP into consumed and remaining', () {
      const totalXp = 150;
      expect(XpService.levelForTotalXp(totalXp), 2);
      expect(XpService.xpIntoLevel(totalXp), 50);
      expect(XpService.xpForCurrentLevel(totalXp), 238);
      expect(XpService.xpToNextLevel(totalXp), 188);
    });

    test('progress is a 0..1 ratio', () {
      expect(XpService.levelProgress(0), 0);
      expect(XpService.levelProgress(50), closeTo(0.5, 0.001));
      expect(XpService.levelProgress(100), 0);
    });

    test('reports full progress at max level', () {
      final capped = XpService.cumulativeXpForLevel(XpService.maxLevel);
      expect(XpService.levelProgress(capped), 1);
      expect(XpService.xpToNextLevel(capped), 0);
    });
  });

  group('xpForAnswer', () {
    test('awards nothing for a wrong answer', () {
      expect(XpService.xpForAnswer(isCorrect: false, combo: 0), 0);
      expect(XpService.xpForAnswer(isCorrect: false, combo: 9), 0);
    });

    test('scales with the combo tiers', () {
      expect(XpService.xpForAnswer(isCorrect: true, combo: 1), 10);
      expect(XpService.xpForAnswer(isCorrect: true, combo: 2), 10);
      expect(XpService.xpForAnswer(isCorrect: true, combo: 3), 12);
      expect(XpService.xpForAnswer(isCorrect: true, combo: 4), 12);
      expect(XpService.xpForAnswer(isCorrect: true, combo: 5), 15);
      expect(XpService.xpForAnswer(isCorrect: true, combo: 12), 15);
    });
  });

  group('rewardedAdBonus', () {
    test('is roughly 25% of the session XP', () {
      expect(XpService.rewardedAdBonus(100), 25);
      expect(XpService.rewardedAdBonus(115), 29);
    });

    test('never rewards a zero-XP session', () {
      expect(XpService.rewardedAdBonus(0), 0);
      expect(XpService.rewardedAdBonus(-10), 0);
    });

    test('always grants at least 1 XP for a positive session', () {
      expect(XpService.rewardedAdBonus(1), 1);
      expect(XpService.rewardedAdBonus(2), 1);
    });
  });

  group('combo', () {
    test('increments on correct answers and resets on a miss', () {
      expect(ComboService.next(current: 0, isCorrect: true), 1);
      expect(ComboService.next(current: 4, isCorrect: true), 5);
      expect(ComboService.next(current: 7, isCorrect: false), 0);
    });

    test('maps to display tiers', () {
      expect(ComboService.tierFor(0), ComboTier.none);
      expect(ComboService.tierFor(1), ComboTier.none);
      expect(ComboService.tierFor(2), ComboTier.small);
      expect(ComboService.tierFor(3), ComboTier.medium);
      expect(ComboService.tierFor(5), ComboTier.onFire);
    });
  });
}
