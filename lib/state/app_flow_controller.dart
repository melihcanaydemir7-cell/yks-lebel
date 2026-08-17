import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Where the user is in the first-run funnel. Drives the router redirects.
class AppFlowState {
  const AppFlowState({
    required this.onboardingCompleted,
    required this.authGateCompleted,
    required this.profileReady,
  });

  final bool onboardingCompleted;

  /// True once the user either signed in or explicitly chose guest mode.
  final bool authGateCompleted;

  /// True once a username exists, so the home screen has something to greet.
  final bool profileReady;

  AppFlowState copyWith({
    bool? onboardingCompleted,
    bool? authGateCompleted,
    bool? profileReady,
  }) => AppFlowState(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    authGateCompleted: authGateCompleted ?? this.authGateCompleted,
    profileReady: profileReady ?? this.profileReady,
  );
}

class AppFlowController extends Notifier<AppFlowState> {
  @override
  AppFlowState build() {
    final store = ref.watch(localStoreProvider);
    final user = ref.watch(currentUserProvider);
    final progress = store.readProgress();
    return AppFlowState(
      onboardingCompleted: store.onboardingCompleted,
      authGateCompleted: store.authGateCompleted || user.isSignedIn,
      profileReady: (progress?.username ?? '').trim().isNotEmpty,
    );
  }

  Future<void> completeOnboarding() async {
    await ref.read(localStoreProvider).setOnboardingCompleted(true);
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> completeAuthGate() async {
    await ref.read(localStoreProvider).setAuthGateCompleted(true);
    state = state.copyWith(authGateCompleted: true);
  }

  void markProfileReady() => state = state.copyWith(profileReady: true);

  /// Sends the user back through auth after signing out.
  Future<void> resetAuthGate() async {
    await ref.read(localStoreProvider).setAuthGateCompleted(false);
    state = state.copyWith(authGateCompleted: false);
  }
}

final appFlowControllerProvider =
    NotifierProvider<AppFlowController, AppFlowState>(AppFlowController.new);
