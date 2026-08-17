class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.avatarId,
    required this.weeklyXp,
    this.isCurrentUser = false,
  });

  final int rank;
  final String userId;
  final String username;
  final int avatarId;
  final int weeklyXp;
  final bool isCurrentUser;

}

class LeaderboardPage {
  const LeaderboardPage({required this.entries, this.currentUserEntry});

  final List<LeaderboardEntry> entries;

  /// Populated only when the current user is outside the visible top slice.
  final LeaderboardEntry? currentUserEntry;

  static const LeaderboardPage empty = LeaderboardPage(entries: []);
}
