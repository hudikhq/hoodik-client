import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../services/trusted_fingerprint_dao.dart';
import '../../../core/widgets/app_icons.dart';

/// Emails of every peer the active account has previously shared with,
/// sorted, for recipient autocomplete. Rows recorded before the email
/// column existed are skipped until a lookup backfills them.
final trustedPeerEmailsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final ownerId = ref.watch(activeServerUserIdProvider);
  if (ownerId == null) return const [];
  final rows = await ref
      .read(databaseProvider)
      .getTrustedFingerprintsForOwner(ownerId);
  final emails = rows.map((r) => r.email).whereType<String>().toSet().toList()
    ..sort();
  return emails;
});

/// Recipient email input shared by the three share surfaces (file dialog,
/// folder member sheet, group member dialog). Autocompletes over the
/// account's trusted peers so a repeat recipient is a tap instead of a
/// retyped address; picking a suggestion immediately runs discovery via
/// [onSelected].
class RecipientEmailField extends ConsumerStatefulWidget {
  const RecipientEmailField({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.enabled,
    required this.onSelected,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final bool enabled;

  /// Called after a suggestion is picked (the controller already holds the
  /// selected email). Surfaces run their discovery flow here.
  final VoidCallback onSelected;

  final VoidCallback? onSubmitted;

  @override
  ConsumerState<RecipientEmailField> createState() =>
      _RecipientEmailFieldState();
}

class _RecipientEmailFieldState extends ConsumerState<RecipientEmailField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        ref.watch(trustedPeerEmailsProvider).valueOrNull ?? const <String>[];
    final enabled = widget.enabled;

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value) {
          if (!enabled || suggestions.isEmpty) return const Iterable.empty();
          final query = value.text.trim().toLowerCase();
          // An empty field lists every known peer — recognition over
          // recall is the point of this widget.
          if (query.isEmpty) return suggestions;
          return suggestions.where((e) => e.toLowerCase().contains(query));
        },
        onSelected: (_) => widget.onSelected(),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: HoodikColors.brownish800,
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 216,
                maxWidth: constraints.maxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final email in options)
                    ListTile(
                      dense: true,
                      leading: Icon(AppIcons.history, size: 18),
                      title: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => select(email),
                    ),
                ],
              ),
            ),
          ),
        ),
        fieldViewBuilder: (context, fieldController, focusNode, _) =>
            AdaptiveTextField(
              controller: fieldController,
              focusNode: focusNode,
              label: widget.label,
              placeholder: widget.placeholder,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              enabled: enabled,
              onSubmitted: (_) => widget.onSubmitted?.call(),
            ),
      ),
    );
  }
}
