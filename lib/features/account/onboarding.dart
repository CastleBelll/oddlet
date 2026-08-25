import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../naming/creature_name.dart';
import 'account_controller.dart';

/// The wall before the app.
///
/// Asked for up front rather than once there is something to lose, which is a
/// real cost: the first egg is the hook and this stands in front of it. What
/// buys it back is that everything the app keeps — the collection, a nickname
/// other people read, a name other people have to live with — belongs to an
/// account, and none of that can be handed to somebody who never chose one.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<UpgradeOutcome> Function() attempt) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final outcome = await attempt();
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      _error = switch (outcome) {
        // Nothing to say: the account is in and this screen is about to go.
        UpgradeOutcome.linked ||
        UpgradeOutcome.switchedToExistingAccount => null,
        // Backing out of a provider sheet is not an error.
        UpgradeOutcome.cancelled => null,
        UpgradeOutcome.badEmail => l10n.signInErrorEmail,
        UpgradeOutcome.weakPassword => l10n.signInErrorPassword,
        UpgradeOutcome.wrongPassword => l10n.signInErrorWrong,
        UpgradeOutcome.failed => l10n.accountFailed,
      };
    });
  }

  void _continueWithEmail(AccountController account) => _run(
    () => account.continueWithEmail(
      email: _email.text.trim(),
      password: _password.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = ref.read(accountProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: oddletVignette),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      l10n.signInTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.signInBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(account.upgradeWithGoogle),
                      child: Text(l10n.accountWithGoogle),
                    ),
                    if (AccountController.supportsApple) ...[
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _run(account.upgradeWithApple),
                        child: Text(l10n.accountWithApple),
                      ),
                    ],
                    const SizedBox(height: 26),
                    _Divider(label: l10n.signInOr),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter,
                      ],
                      decoration: InputDecoration(labelText: l10n.signInEmail),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: l10n.signInPassword,
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _continueWithEmail(account),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _continueWithEmail(account),
                      child: Text(l10n.signInContinue),
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

/// Asked straight after signing in, because the very next thing the app can
/// offer is naming something, and a name has to be signed by somebody.
class HandleScreen extends ConsumerStatefulWidget {
  const HandleScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<HandleScreen> createState() => _HandleScreenState();
}

class _HandleScreenState extends ConsumerState<HandleScreen> {
  final _handle = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final handle = tidyName(_handle.text);

    // Checked here so the field can object without a round trip. The server
    // checks again, and the server is the one that decides.
    final problem = checkName(handle);
    if (problem != null) {
      setState(() => _error = _say(l10n, problem));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('setHandle')
          .call<Object?>({'handle': handle});
      if (mounted) {
        widget.onDone();
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = (error.message ?? '').endsWith(':blocked')
            ? l10n.nameErrorBlocked
            : l10n.nameErrorHandle;
      });
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'oddlet',
          context: ErrorDescription('setting a handle'),
        ),
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.nameErrorUnreachable;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: oddletVignette),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.handleTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.handleBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _handle,
                      autofocus: true,
                      enabled: !_busy,
                      maxLength: nameMaxLength,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.nameItHandle,
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(l10n.handleContinue),
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

String _say(AppLocalizations l10n, NameProblem problem) => switch (problem) {
  NameProblem.blank || NameProblem.tooShort => l10n.nameErrorTooShort,
  NameProblem.tooLong => l10n.nameErrorTooLong,
  NameProblem.badCharacters => l10n.nameErrorBadCharacters,
  NameProblem.repeats => l10n.nameErrorRepeats,
};

class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.colorScheme.surfaceContainerHighest),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.colorScheme.surfaceContainerHighest),
        ),
      ],
    );
  }
}
