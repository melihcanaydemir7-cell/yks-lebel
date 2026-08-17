import 'package:flutter/material.dart';

import '../data/models/progress.dart';
import '../domain/achievement.dart';
import '../domain/daily_quest.dart';
import '../domain/league.dart';
import '../l10n/app_localizations.dart';
import 'theme/app_palette.dart';

/// Maps stable domain identifiers to localized, user-facing strings. Domain
/// code never carries Turkish text so future locales are a pure ARB change.
class L10nMaps {
  const L10nMaps._();

  static String quest(L10n l10n, String questId) {
    switch (questId) {
      case DailyQuests.solveFive:
        return l10n.questSolveFive;
      case DailyQuests.correctFive:
        return l10n.questCorrectFive;
      case DailyQuests.mathSession:
        return l10n.questMathSession;
      case DailyQuests.dailyQuestion:
        return l10n.questDailyQuestion;
      default:
        return questId;
    }
  }

  static String achievementName(L10n l10n, String id) {
    switch (id) {
      case 'first_step':
        return l10n.achFirstStepName;
      case 'warming_up':
        return l10n.achWarmingUpName;
      case 'hundred':
        return l10n.achHundredName;
      case 'streak_start':
        return l10n.achStreakStartName;
      case 'one_week':
        return l10n.achOneWeekName;
      case 'on_fire':
        return l10n.achOnFireName;
      case 'mathematician':
        return l10n.achMathematicianName;
      default:
        return id;
    }
  }

  static String achievementBody(L10n l10n, String id) {
    switch (id) {
      case 'first_step':
        return l10n.achFirstStepBody;
      case 'warming_up':
        return l10n.achWarmingUpBody;
      case 'hundred':
        return l10n.achHundredBody;
      case 'streak_start':
        return l10n.achStreakStartBody;
      case 'one_week':
        return l10n.achOneWeekBody;
      case 'on_fire':
        return l10n.achOnFireBody;
      case 'mathematician':
        return l10n.achMathematicianBody;
      default:
        return '';
    }
  }

  static String league(L10n l10n, League league) {
    switch (league) {
      case League.bronze:
        return l10n.leagueBronze;
      case League.silver:
        return l10n.leagueSilver;
      case League.gold:
        return l10n.leagueGold;
      case League.platinum:
        return l10n.leaguePlatinum;
      case League.diamond:
        return l10n.leagueDiamond;
    }
  }

  static Color leagueColor(League league) {
    switch (league) {
      case League.bronze:
        return AppPalette.bronze;
      case League.silver:
        return AppPalette.silver;
      case League.gold:
        return AppPalette.gold;
      case League.platinum:
        return AppPalette.platinum;
      case League.diamond:
        return AppPalette.diamond;
    }
  }

  static String examTrack(L10n l10n, ExamTrack track) {
    switch (track) {
      case ExamTrack.tyt:
        return l10n.trackTyt;
      case ExamTrack.sayisal:
        return l10n.trackSayisal;
      case ExamTrack.esitAgirlik:
        return l10n.trackEsitAgirlik;
      case ExamTrack.sozel:
        return l10n.trackSozel;
      case ExamTrack.dil:
        return l10n.trackDil;
      case ExamTrack.undecided:
        return l10n.trackUndecided;
    }
  }

  /// Mastery label from the number of solved questions in a subject.
  static String mastery(L10n l10n, int solved) {
    if (solved == 0) return l10n.masteryNew;
    if (solved < 20) return l10n.masteryBeginner;
    if (solved < 60) return l10n.masteryIntermediate;
    if (solved < 150) return l10n.masteryAdvanced;
    return l10n.masteryMaster;
  }

  static String achievementIcon(String id) =>
      Achievements.byId(id)?.icon ?? '🏅';

  /// Subject icons are referenced by name in the seed data so the catalog can
  /// live in the database without shipping icon assets.
  static IconData subjectIcon(String name) {
    switch (name) {
      case 'calculate':
        return Icons.calculate_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'change_history':
        return Icons.change_history_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'eco':
        return Icons.eco_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'public':
        return Icons.public_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'functions':
        return Icons.functions_rounded;
      case 'rocket_launch':
        return Icons.rocket_launch_rounded;
      case 'biotech':
        return Icons.biotech_rounded;
      case 'coronavirus':
        return Icons.coronavirus_rounded;
      case 'history_edu':
        return Icons.history_edu_rounded;
      default:
        return Icons.school_rounded;
    }
  }
}
