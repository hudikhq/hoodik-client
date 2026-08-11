import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

class AiAccessTile extends StatelessWidget {
  const AiAccessTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.bolt : Icons.smart_toy_outlined,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountAiAccessTitle),
      subtitle: Text(l10n.accountAiAccessSubtitle),
      onTap: () => context.push('/mcp-settings'),
    );
  }
}
