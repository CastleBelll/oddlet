import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../ui/oddlet_dialog.dart';
import '../naming/naming_repository.dart';
import 'account_controller.dart';

/// The only settings screen the app has: who you are, and how to stop being it.
///
/// Deleting an account has to be reachable from inside the app, not only by
/// writing to an address on a web page, and the same screen is the honest place
/// to say what deleting one actually does.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await ref.read(accountProvider.notifier).signOut();
    // No pop: with no account the app shows the sign-in wall in place of
    // everything, and this route goes with it.
  }

  Future<void> _delete() async {
    if (_busy) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final sure = await showOddletChoice(
      context,
      title: l10n.accountDeleteTitle,
      message: l10n.accountDeleteBody,
      confirmLabel: l10n.accountDeleteConfirm,
      cancelLabel: l10n.accountDeleteCancel,
    );
    if (!sure || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final done = await ref.read(accountProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }
    if (done) {
      // Same as signing out: there is no account left to show this screen to.
      return;
    }

    setState(() => _busy = false);
    await showOddletMessage(context, l10n.accountDeleteFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final handle = ref.watch(handleProvider).value ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: oddletVignette),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.nameItHandle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      handle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 44),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _signOut,
                      child: Text(l10n.accountSignOut),
                    ),
                    const SizedBox(height: 44),
                    Text(
                      l10n.accountDeleteExplain,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(l10n.accountDelete),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
