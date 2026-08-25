import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What happened when someone tried to keep their account.
enum UpgradeOutcome {
  /// The anonymous account became a real one, keeping everything.
  linked,

  /// The credential already belonged to another account, and the user is now
  /// signed into that one. Whatever the anonymous account held is not theirs
  /// any more, and they have to be told.
  switchedToExistingAccount,

  cancelled,
  failed,
}

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

  /// Whether Apple can be offered here at all.
  static bool get supportsApple => !kIsWeb && Platform.isIOS;

  Future<UpgradeOutcome> upgradeWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return UpgradeOutcome.failed;
      }
      return _link(GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (error) {
      return error.code == GoogleSignInExceptionCode.canceled
          ? UpgradeOutcome.cancelled
          : _report(error, StackTrace.current, 'signing in with Google');
    } catch (error, stack) {
      return _report(error, stack, 'signing in with Google');
    }
  }

  Future<UpgradeOutcome> upgradeWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      return _link(
        OAuthProvider('apple.com').credential(
          idToken: apple.identityToken,
          accessToken: apple.authorizationCode,
        ),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      return error.code == AuthorizationErrorCode.canceled
          ? UpgradeOutcome.cancelled
          : _report(error, StackTrace.current, 'signing in with Apple');
    } catch (error, stack) {
      return _report(error, stack, 'signing in with Apple');
    }
  }

  /// Attaches [credential] to the account the user is already using, so a
  /// collection found before signing in comes along.
  Future<UpgradeOutcome> _link(AuthCredential credential) async {
    final auth = FirebaseAuth.instance;
    try {
      final result = await auth.currentUser!.linkWithCredential(credential);
      state = AsyncData(result.user);
      return UpgradeOutcome.linked;
    } on FirebaseAuthException catch (error, stack) {
      if (error.code != 'credential-already-in-use' &&
          error.code != 'email-already-in-use') {
        return _report(error, stack, 'linking an account');
      }

      // Someone signing in with an account they already have. Their real
      // collection is the one on that account, so hand it back rather than
      // refusing, and let the caller say what became of the anonymous one.
      final result = await auth.signInWithCredential(credential);
      state = AsyncData(result.user);
      return UpgradeOutcome.switchedToExistingAccount;
    }
  }

  UpgradeOutcome _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'oddlet',
        context: ErrorDescription(context),
      ),
    );
    return UpgradeOutcome.failed;
  }
}

/// The web client Firebase issues for this project. Google hands back an id
/// token minted for it, which is what Firebase will accept.
const _serverClientId =
    '626132539773-krib0ams3pvq03dguvttvm0flpaaccto.apps.googleusercontent.com';
