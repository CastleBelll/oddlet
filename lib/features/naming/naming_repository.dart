import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_controller.dart';
import 'species_name.dart';

/// Why a name was refused.
///
/// Every one of these has to be sayable to the person who typed it, which is
/// why the list is short and none of them is "error".
enum NameRejection {
  blank,
  tooShort,
  tooLong,
  badCharacters,
  repeats,

  /// The word list said no.
  blocked,

  /// Some other creature already carries that name.
  taken,

  /// Somebody named this creature first. There is no second try at this one,
  /// so it is worth saying plainly rather than as a failure.
  alreadyNamed,

  /// The nickname was the problem, not the name.
  handleProblem,

  /// Naming asks everyone to live with a name somebody chose, so an account
  /// nobody can be asked about does not get to write one.
  needsAccount,

  unreachable,
  unknown,
}

/// Where the naming function lives. Naming is rare and a little slow already;
/// a round trip to another continent would be felt.
const _region = 'asia-northeast3';

final namingRepositoryProvider = Provider<NamingRepository>(
  (ref) => NamingRepository(),
);

/// The nickname this account signs its names with, or null before it has one.
///
/// Its own provider rather than a field on the account, so that finishing the
/// nickname step can invalidate it and the app moves on by itself.
final handleProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(accountProvider).value?.uid;
  if (uid == null) {
    return null;
  }
  return ref.watch(namingRepositoryProvider).myHandle(uid);
});

/// The name of one species, if it has one.
///
/// Watches the account, because whether a name is *yours* depends on who you
/// are, and signing in changes the answer.
final speciesNameProvider = FutureProvider.family<SpeciesName?, int>((
  ref,
  species,
) async {
  await ref.watch(accountProvider.future);
  return ref.watch(namingRepositoryProvider).lookup(species);
});

class NamingRepository {
  /// The name this species already has, or null if nobody has named it.
  ///
  /// A species with no document is a species with no name. That is the whole
  /// of the rule, and it is why declining to name one simply leaves it open
  /// for whoever finds it next.
  Future<SpeciesName?> lookup(int species) async {
    try {
      final document = await FirebaseFirestore.instance
          .doc('species/$species')
          .get();
      final data = document.data();
      if (data == null) {
        return null;
      }
      return SpeciesName.fromFirestore(species, _readable(data));
    } catch (error, stack) {
      // A name that cannot be read shows as a creature without one, which is
      // wrong in the recoverable direction: the naming attempt that follows
      // is refused by the server rather than overwriting anything.
      _report(error, stack, 'reading the name of species $species');
      return null;
    }
  }

  /// The nickname this account already signs names with, if it has one.
  ///
  /// Only used to decide whether to ask for one. The server reads it again and
  /// keeps whatever it finds, so an app that got this wrong cannot overwrite
  /// a handle somebody already has.
  Future<String?> myHandle(String uid) async {
    try {
      final handle = (await FirebaseFirestore.instance
              .doc('users/$uid')
              .get())
          .data()?['handle'];
      return handle is String && handle.isNotEmpty ? handle : null;
    } catch (error, stack) {
      // Wrong in the harmless direction: the sheet asks for a nickname that
      // then turns out to be unnecessary, and the server keeps the old one.
      _report(error, stack, 'reading a handle');
      return null;
    }
  }

  /// Claims [name] for [species], signed with [handle].
  ///
  /// Returns null once the name is registered. The app checks the shape of a
  /// name first so it can object while someone types, but this call is what
  /// decides: the checks in the app are readable and editable by anyone, and
  /// the ones on the server are not.
  Future<NameRejection?> register({
    required int species,
    required String name,
    String? handle,
  }) async {
    try {
      await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('registerName')
          .call<Object?>({
            'speciesId': species,
            'name': name,
            'handle': ?handle,
          });
      return null;
    } on FirebaseFunctionsException catch (error, stack) {
      final rejection = rejectionFor(error.code, error.message);
      if (rejection == NameRejection.unknown) {
        _report(error, stack, 'registering a name');
      }
      return rejection;
    } catch (error, stack) {
      _report(error, stack, 'registering a name');
      return NameRejection.unreachable;
    }
  }
}

/// Turns what the function said into something the app can say.
///
/// The function answers with `field:problem`, so one string carries both
/// which box was wrong and what was wrong with it.
@visibleForTesting
NameRejection rejectionFor(String code, String? message) {
  if (code == 'unauthenticated' || code == 'permission-denied') {
    return NameRejection.needsAccount;
  }
  if (code == 'unavailable' || code == 'deadline-exceeded') {
    return NameRejection.unreachable;
  }

  final parts = (message ?? '').split(':');
  if (parts.first == 'handle') {
    return NameRejection.handleProblem;
  }

  return switch (parts.length > 1 ? parts[1] : '') {
    'blank' => NameRejection.blank,
    'tooShort' => NameRejection.tooShort,
    'tooLong' => NameRejection.tooLong,
    'badCharacters' => NameRejection.badCharacters,
    'repeats' => NameRejection.repeats,
    'blocked' => NameRejection.blocked,
    'taken' => NameRejection.taken,
    'named' => NameRejection.alreadyNamed,
    _ => NameRejection.unknown,
  };
}

Map<String, Object?> _readable(Map<String, Object?> data) => {
  ...data,
  // Unwrapped here rather than in the model, so the model stays free of the
  // Firestore SDK and can be built in a plain test.
  'namedAt': data['namedAt'] is Timestamp
      ? (data['namedAt']! as Timestamp).toDate()
      : null,
};

void _report(Object error, StackTrace stack, String context) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'oddlet',
      context: ErrorDescription(context),
    ),
  );
}
