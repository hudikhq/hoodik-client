import 'package:flutter/material.dart';

/// Turn a global point into the `RelativeRect` that `showMenu` expects.
///
/// `showMenu` measures its rect against the enclosing overlay, and that
/// overlay belongs to the branch navigator — which starts beside the
/// navigation rail at desktop widths, not at the window origin. Handing it a
/// raw global point opens the menu a rail-width away from the row it belongs
/// to, so every caller has to convert first.
RelativeRect menuAnchorAt(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final local = overlay.globalToLocal(globalPosition);
  return RelativeRect.fromLTRB(
    local.dx,
    local.dy,
    overlay.size.width - local.dx,
    overlay.size.height - local.dy,
  );
}
