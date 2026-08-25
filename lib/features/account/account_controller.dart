import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accountProvider = AsyncNotifierProvider<AccountController, User?>(
  AccountController.new,
);

/// Who the user is, as far as the backend is concerned.
///
/// Everyone starts anonymous and stays that way until they have a reason not
/// to. Asking for an account before someone has seen an egg would spend the
/// whole opening on a form; the account starts mattering once there is a
/// collection worth keeping, or a name worth putting someone's word behind.
///
/// The same account is later upgraded to Google, Apple or email in place, so
/// nothing found before signing in is lost.
class AccountController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final auth = FirebaseAuth.instance;
    final existing = auth.currentUser;
    if (existing != null) {
      return existing;
    }

    try {
      final credential = await auth.signInAnonymously();
      return credential.user;
    } on FirebaseAuthException catch (error, stack) {
      // The app is playable without an account: today's egg lives on the
      // device. Report it and carry on rather than blocking the loop on a
      // network that may not be there.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'oddlet',
          context: ErrorDescription('signing in'),
        ),
      );
      return null;
    }
  }

  /// Whether this is still the throwaway account.
  ///
  /// A find named by an anonymous account cannot be answered for, so naming a
  /// first discovery waits until this is false.
  bool get isAnonymous => state.value?.isAnonymous ?? true;
}
