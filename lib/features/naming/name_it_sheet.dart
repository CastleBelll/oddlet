import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/oddlet_dialog.dart';
import '../account/account_controller.dart';
import '../account/account_upgrade_sheet.dart';
import 'creature_name.dart';
import 'naming_repository.dart';

/// Asks what to call a creature nobody has named, and registers the answer.
///
/// Returns the registered name, or null if the user left without naming it.
Future<String?> showNameItSheet(
  BuildContext context, {
  required int species,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Leaving without naming hands the chance to somebody else, so it is a
    // decision made in the sheet rather than by tapping the dark behind it.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _NameItSheet(species: species),
  );
}

class _NameItSheet extends ConsumerStatefulWidget {
  const _NameItSheet({required this.species});

  final int species;

  @override
  ConsumerState<_NameItSheet> createState() => _NameItSheetState();
}

class _NameItSheetState extends ConsumerState<_NameItSheet> {
  final _name = TextEditingController();
  final _handle = TextEditingController();

  /// Null until the account has been asked. A nickname is only requested from
  /// someone who has never set one.
  bool? _needsHandle;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _askAboutHandle();
  }

  Future<void> _askAboutHandle() async {
    final uid = ref.read(accountProvider).value?.uid;
    final existing = uid == null
        ? null
        : await ref.read(namingRepositoryProvider).myHandle(uid);

    if (mounted) {
      setState(() => _needsHandle = existing == null);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final name = tidyName(_name.text);

    // Checked here so the field can object without a round trip. The server
    // checks again, and it is the server that decides.
    final problem = checkName(name);
    if (problem != null) {
      setState(
        () => _error = _sayProblem(AppLocalizations.of(context), problem),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final rejection = await ref
        .read(namingRepositoryProvider)
        .register(
          species: widget.species,
          name: name,
          handle: (_needsHandle ?? false) ? tidyName(_handle.text) : null,
        );

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (rejection == null) {
      // Everyone who finds this creature from now on reads this name.
      ref.invalidate(speciesNameProvider(widget.species));
      Navigator.of(context).pop(name);
      return;
    }

    if (rejection == NameRejection.needsAccount) {
      await showAccountUpgradeSheet(context);
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).nameErrorNeedsAccount,
        );
      }
      return;
    }

    // Somebody else got there while this was being typed. There is no second
    // try at this creature, so the sheet closes rather than inviting another
    // name for something that now has one.
    if (rejection == NameRejection.alreadyNamed) {
      ref.invalidate(speciesNameProvider(widget.species));
      await showOddletMessage(
        context,
        AppLocalizations.of(context).nameErrorAlreadyNamed,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(
      () => _error = _sayRejection(AppLocalizations.of(context), rejection),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          8,
          28,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.nameItTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.nameItBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: nameMaxLength,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.nameItField,
                errorText: _error,
              ),
              // Newlines would be stripped anyway; refusing them here keeps
              // the field one line high while it happens.
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
              ],
              onSubmitted: (_) => _submit(),
            ),
            if (_needsHandle ?? false) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _handle,
                maxLength: nameMaxLength,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.nameItHandle,
                  helperText: l10n.nameItHandleHint,
                  helperMaxLines: 2,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _needsHandle == null ? null : _submit,
              child: Text(l10n.nameItSubmit),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(
                l10n.nameItLater,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
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
    );
  }
}

String _sayProblem(AppLocalizations l10n, NameProblem problem) =>
    switch (problem) {
      NameProblem.blank || NameProblem.tooShort => l10n.nameErrorTooShort,
      NameProblem.tooLong => l10n.nameErrorTooLong,
      NameProblem.badCharacters => l10n.nameErrorBadCharacters,
      NameProblem.repeats => l10n.nameErrorRepeats,
    };

String _sayRejection(AppLocalizations l10n, NameRejection rejection) =>
    switch (rejection) {
      NameRejection.blank || NameRejection.tooShort => l10n.nameErrorTooShort,
      NameRejection.tooLong => l10n.nameErrorTooLong,
      NameRejection.badCharacters => l10n.nameErrorBadCharacters,
      NameRejection.repeats => l10n.nameErrorRepeats,
      NameRejection.blocked => l10n.nameErrorBlocked,
      NameRejection.taken => l10n.nameErrorTaken,
      NameRejection.alreadyNamed => l10n.nameErrorAlreadyNamed,
      NameRejection.handleProblem => l10n.nameErrorHandle,
      NameRejection.needsAccount => l10n.nameErrorNeedsAccount,
      NameRejection.unreachable => l10n.nameErrorUnreachable,
      NameRejection.unknown => l10n.nameErrorUnknown,
    };
