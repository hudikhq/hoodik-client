import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';

/// Reusable loading/progress indicator for preview widgets.
///
/// [progress] controls the circular indicator:
///   - `null` → indeterminate spinner (no percentage)
///   - negative → indeterminate spinner with stage label (no percentage)
///   - 0.0–1.0 → determinate ring with percentage text
///
/// [stage] is an optional label shown below the progress (e.g. "Downloading",
/// "Decrypting").
class PreviewLoading extends StatelessWidget {
  final double? progress;
  final String? stage;
  final Uint8List? thumbnailBytes;

  const PreviewLoading({
    super.key,
    this.progress,
    this.stage,
    this.thumbnailBytes,
  });

  @override
  Widget build(BuildContext context) {
    // Negative progress means indeterminate with a stage label.
    final isIndeterminate = progress == null || progress! < 0;
    final showPercentage = !isIndeterminate && progress! >= 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred thumbnail background if available
        if (thumbnailBytes != null)
          Opacity(
            opacity: 0.3,
            child: Image.memory(
              thumbnailBytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const SizedBox.shrink(),
            ),
          ),

        // Progress indicator
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: isIndeterminate ? null : progress,
                  color: HoodikColors.iconCrimson,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 12),
              if (stage != null)
                Text(
                  showPercentage
                      ? '$stage ${(progress! * 100).toInt()}%'
                      : '$stage...',
                  style: const TextStyle(
                    color: HoodikColors.textMuted,
                    fontSize: 13,
                  ),
                )
              else if (showPercentage)
                Text(
                  '${(progress! * 100).toInt()}%',
                  style: const TextStyle(
                    color: HoodikColors.textMuted,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
