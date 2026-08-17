import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// The app's own notion of a session. Guest mode is a first-class state: the
/// whole study loop works without an account.
class AppUser {
  const AppUser({this.id, this.email, this.isGuest = true});

  final String? id;
  final String? email;
  final bool isGuest;

  bool get isSignedIn => !isGuest && id != null;

  static const AppUser guest = AppUser();
}

/// Turkish-facing errors are produced by the UI layer; this enum keeps the
/// service free of localized strings.
enum AuthFailure {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  network,
  notConfigured,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure);
  final AuthFailure failure;
}

class AuthService {
  AuthService([this._client]);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  AppUser get currentUser {
    final user = _client?.auth.currentUser;
    if (user == null) return AppUser.guest;
    return AppUser(id: user.id, email: user.email, isGuest: false);
  }

  Stream<AppUser> authStateChanges() {
    final client = _client;
    if (client == null) return Stream<AppUser>.value(AppUser.guest);
    return client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return AppUser.guest;
      return AppUser(id: user.id, email: user.email, isGuest: false);
    });
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AuthException(AuthFailure.invalidCredentials);
      return AppUser(id: user.id, email: user.email, isGuest: false);
    } on AuthApiException catch (error) {
      throw AuthException(_mapApiError(error));
    } catch (_) {
      throw const AuthException(AuthFailure.network);
    }
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    String? username,
  }) async {
    final client = _requireClient();
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: username == null ? null : <String, dynamic>{'username': username},
      );
      final user = response.user;
      if (user == null) throw const AuthException(AuthFailure.unknown);
      return AppUser(id: user.id, email: user.email, isGuest: false);
    } on AuthApiException catch (error) {
      throw AuthException(_mapApiError(error));
    } catch (_) {
      throw const AuthException(AuthFailure.network);
    }
  }

  /// Google sign-in goes through Supabase's OAuth redirect rather than the
  /// native Google SDK: it needs no extra client ids in the app and keeps the
  /// iOS port simple. See README "Supabase Setup".
  Future<void> signInWithGoogle() async {
    final client = _requireClient();
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (_) {
      throw const AuthException(AuthFailure.network);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final client = _requireClient();
    try {
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.authRedirectUrl,
      );
    } catch (_) {
      throw const AuthException(AuthFailure.network);
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Signing out locally is enough for the UI to move on.
    }
  }

  /// Deletes the account and all of its rows. Requires the `delete_account`
  /// RPC created in migration 0003 (it runs as SECURITY DEFINER).
  Future<void> deleteAccount() async {
    final client = _requireClient();
    await client.rpc<void>('delete_account');
    await client.auth.signOut();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) throw const AuthException(AuthFailure.notConfigured);
    return client;
  }

  AuthFailure _mapApiError(AuthApiException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return AuthFailure.emailAlreadyRegistered;
    }
    if (message.contains('password')) {
      return message.contains('short') || message.contains('least')
          ? AuthFailure.weakPassword
          : AuthFailure.invalidCredentials;
    }
    if (message.contains('invalid')) return AuthFailure.invalidCredentials;
    return AuthFailure.unknown;
  }
}
