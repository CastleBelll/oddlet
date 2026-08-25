import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
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

  /// The address is not an address.
  badEmail,

  /// Firebase will not take a password that short.
  weakPassword,

  /// That address exists and the password does not open it.
  wrongPassword,
}

final accountProvider = AsyncNotifierProvider<AccountController, User?>(
  AccountController.new,
);

/// Who the user is, as far as the backend is concerned.
///
/// Null until somebody has signed in, and the app does not start without one.
/// Nothing signs itself in quietly here: an account that appeared on its own is
/// an account nobody chose, and this one carries a nickname other people read
/// and names other people have to live with.
class AccountController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async => FirebaseAuth.instance.currentUser;

  /// Sends the user back to the sign-in wall.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = const AsyncData(null);
  }

  /// Deletes the account and everything on it, then puts the user back at the
  /// sign-in wall. Returns false if nothing was deleted.
  ///
  /// The work happens in a function rather than here: rules refuse a delete on
  /// a collection document or a user document from any client, which is what
  /// keeps a bug from erasing somebody's finds. Doing it server-side also
  /// sidesteps `requires-recent-login` — the Admin SDK does not ask an account
  /// that has been signed in for a fortnight to prove itself first, which would
  /// mean a second sign-in prompt in the middle of leaving.
  Future<bool> deleteAccount() async {
    try {
      await FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable('deleteAccount')
          .call<Object?>();
    } catch (error, stack) {
      _report(error, stack, 'deleting an account');
      return false;
    }

    // The account is gone; the session on this phone is the only thing left.
    await signOut();
    return true;
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

  /// Signs in with [credential], or attaches it to a throwaway account already
  /// in use so that anything found under it comes along.
  Future<UpgradeOutcome> _link(AuthCredential credential) async {
    final auth = FirebaseAuth.instance;
    final existing = auth.currentUser;

    // Nothing to attach it to. Now that the app asks for an account before it
    // starts, this is the ordinary path and linking is the exception.
    if (existing == null || !existing.isAnonymous) {
      final result = await auth.signInWithCredential(credential);
      state = AsyncData(result.user);
      return UpgradeOutcome.linked;
    }

    try {
      final result = await existing.linkWithCredential(credential);
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

  /// Signs in with an email address, creating the account if it is new.
  ///
  /// One button rather than two. Whether an address has been here before is
  /// something the server already knows, and making somebody pick the right
  /// door first is a question asked for the implementation's benefit.
  Future<UpgradeOutcome> continueWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      state = AsyncData(auth.currentUser);
      return UpgradeOutcome.linked;
    } on FirebaseAuthException catch (error, stack) {
      if (error.code != 'user-not-found') {
        return _reportEmail(error, stack);
      }
      try {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        state = AsyncData(auth.currentUser);
        return UpgradeOutcome.linked;
      } on FirebaseAuthException catch (error, stack) {
        return _reportEmail(error, stack);
      }
    }
  }

  /// Told apart from everything else because these are the failures somebody
  /// can actually do something about: a typo in the address, a password too
  /// short, one that does not open the account that address already has.
  UpgradeOutcome _reportEmail(FirebaseAuthException error, StackTrace stack) =>
      switch (error.code) {
        'invalid-email' => UpgradeOutcome.badEmail,
        'weak-password' => UpgradeOutcome.weakPassword,
        'wrong-password' ||
        'invalid-credential' ||
        'email-already-in-use' => UpgradeOutcome.wrongPassword,
        _ => _report(error, stack, 'signing in with an email address'),
      };

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

/// Where the account functions live, alongside the naming one.
const _functionsRegion = 'asia-northeast3';

/// The web client Firebase issues for this project. Google hands back an id
/// token minted for it, which is what Firebase will accept.
const _serverClientId =
    '626132539773-krib0ams3pvq03dguvttvm0flpaaccto.apps.googleusercontent.com';
