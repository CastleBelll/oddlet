import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'account_controller.dart';

/// Offers the ways to turn the throwaway account into a real one.
///
/// The reason given is keeping what you already have, not unlocking anything.
/// Nobody signs in for features they have not met yet.
Future<void> showAccountUpgradeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AccountUpgradeSheet(),
  );
}

class _AccountUpgradeSheet extends ConsumerStatefulWidget {
  const _AccountUpgradeSheet();

  @override
  ConsumerState<_AccountUpgradeSheet> createState() =>
      _AccountUpgradeSheetState();
}

class _AccountUpgradeSheetState extends ConsumerState<_AccountUpgradeSheet> {
  bool _busy = false;

  Future<void> _run(Future<UpgradeOutcome> Function() upgrade) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    final outcome = await upgrade();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    final l10n = AppLocalizations.of(context);
    final message = switch (outcome) {
      UpgradeOutcome.linked => l10n.accountLinked,
      // Deliberately spelled out. Quietly moving someone onto another account
      // and letting them wonder where their collection went would be worse
      // than telling them.
      UpgradeOutcome.switchedToExistingAccount => l10n.accountSwitched,
      UpgradeOutcome.failed => l10n.accountFailed,
      UpgradeOutcome.cancelled => null,
    };

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    if (outcome != UpgradeOutcome.failed &&
        outcome != UpgradeOutcome.cancelled) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = ref.read(accountProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.accountSheetTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.accountSheetBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : () => _run(account.upgradeWithGoogle),
              child: Text(l10n.accountWithGoogle),
            ),
            if (AccountController.supportsApple) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _run(account.upgradeWithApple),
                child: Text(l10n.accountWithApple),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
