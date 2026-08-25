import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Says one thing, in the middle of the screen, and waits to be dismissed.
///
/// The app has no toasts. A message that slides in at the bottom and leaves on
/// a timer is a message the user can miss while looking at an egg, and the few
/// things this app has to say — an account linked, an account swapped — are
/// things they have to actually read.
Future<void> showOddletMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(28, 32, 28, 12),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).dialogDismiss),
          ),
        ],
      );
    },
  );
}
