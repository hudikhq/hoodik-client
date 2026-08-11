import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/hoodik_colors.dart';

/// Whether the current platform uses iOS-style (Cupertino) widgets.
bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

/// A scaffold that renders a [CupertinoPageScaffold] on Apple platforms and a
/// Material [Scaffold] elsewhere.
///
/// For screens that need an AppBar / NavigationBar, pass [navigationBar] (iOS)
/// or [appBar] (Material).  Only the platform-appropriate one is used.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.navigationBar,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  final ObstructingPreferredSizeWidget? navigationBar;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: navigationBar,
        backgroundColor:
            backgroundColor ??
            CupertinoTheme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        child: body,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: isDestructive
              ? CupertinoColors.destructiveRed
              : CupertinoTheme.of(context).primaryColor,
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: isDestructive
            ? ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              )
            : null,
        child: child,
      ),
    );
  }
}

class AdaptiveTextButton extends StatelessWidget {
  const AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: isDestructive ? CupertinoColors.destructiveRed : null,
          ),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: isDestructive
          ? TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            )
          : null,
      child: child,
    );
  }
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.autofocus = false,
    this.maxLength,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final String? label;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool autofocus;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
          CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            placeholder: placeholder ?? label,
            prefix: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: prefix,
                  )
                : null,
            suffix: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffix,
                  )
                : null,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autocorrect: autocorrect,
            autofocus: autofocus,
            maxLength: maxLength,
            onSubmitted: onSubmitted,
            enabled: enabled,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          ),
        ],
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      autofocus: autofocus,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      enabled: enabled,
    );
  }
}

/// An [AdaptiveTextField] pre-configured for password/PIN entry with a
/// built-in visibility toggle. Manages its own obscure state internally.
class AdaptivePasswordField extends StatefulWidget {
  const AdaptivePasswordField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AdaptivePasswordField> createState() => _AdaptivePasswordFieldState();
}

class _AdaptivePasswordFieldState extends State<AdaptivePasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return AdaptiveTextField(
      controller: widget.controller,
      label: widget.label,
      placeholder: widget.placeholder,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      obscureText: _obscure,
      prefix: Icon(
        isApplePlatform ? CupertinoIcons.lock : Icons.lock_outline,
        size: 18,
        color: iconColor,
      ),
      suffix: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Icon(
          _obscure
              ? (isApplePlatform
                    ? CupertinoIcons.eye
                    : Icons.visibility_outlined)
              : (isApplePlatform
                    ? CupertinoIcons.eye_slash
                    : Icons.visibility_off_outlined),
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }
}

Future<T?> showAdaptiveAlert<T>({
  required BuildContext context,
  required String title,
  String? content,
  required List<AdaptiveDialogAction<T>> actions,
}) {
  if (isApplePlatform) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: actions.map((a) {
          return CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, a.value),
            isDestructiveAction: a.isDestructive,
            isDefaultAction: a.isDefault,
            child: Text(a.label),
          );
        }).toList(),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: actions.map((a) {
          return TextButton(
            onPressed: () => Navigator.pop(ctx, a.value),
            style: a.isDestructive
                ? TextButton.styleFrom(
                    foregroundColor: HoodikColors.textCrimson,
                  )
                : null,
            child: Text(a.label),
          );
        }).toList(),
      );
    },
  );
}

class AdaptiveDialogAction<T> {
  const AdaptiveDialogAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final T value;
  final bool isDestructive;
  final bool isDefault;
}

class AdaptiveListSection extends StatelessWidget {
  const AdaptiveListSection({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoListSection.insetGrouped(
        header: header != null ? Text(header!) : null,
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              header!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
        Card(
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [if (i > 0) const Divider(height: 1), children[i]],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing:
            trailing ??
            (onTap != null ? const CupertinoListTileChevron() : null),
        onTap: onTap,
      );
    }

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class AdaptiveLoadingIndicator extends StatelessWidget {
  const AdaptiveLoadingIndicator({super.key, this.radius = 10.0});

  final double radius;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoActivityIndicator(radius: radius);
    }
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Returns a Cupertino-style icon on Apple platforms, Material icon otherwise.
/// Use this for icons that have well-known equivalents.
IconData adaptiveIcon({
  required IconData material,
  required IconData cupertino,
}) {
  return isApplePlatform ? cupertino : material;
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final Color errorColor;
    final Color errorBg;

    if (isApplePlatform) {
      errorColor = CupertinoColors.systemRed.resolveFrom(context);
      errorBg = CupertinoColors.systemRed
          .resolveFrom(context)
          .withValues(alpha: 0.12);
    } else {
      // The message reads on the crimson text step, not on `colorScheme.error`
      // — that role is the fill this banner is tinted with, and it measures
      // 2.4:1 when borrowed as a foreground.
      errorColor = HoodikColors.textCrimson;
      errorBg = Theme.of(context).colorScheme.error.withValues(alpha: 0.1);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isApplePlatform
                ? CupertinoIcons.exclamationmark_circle
                : Icons.error_outline,
            color: errorColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: errorColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
