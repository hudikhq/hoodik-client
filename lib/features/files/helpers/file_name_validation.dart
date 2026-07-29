import '../../../core/utils/l10n_lookup.dart';

/// Validation outcome for a user-entered file or folder name.
sealed class NameValidation {
  const NameValidation();
}

class NameOk extends NameValidation {
  final String trimmed;
  const NameOk(this.trimmed);
}

class NameInvalid extends NameValidation {
  final String reason;
  const NameInvalid(this.reason);
}

/// Sentinel value for "user typed nothing, or whitespace only, or a
/// string identical to [current]" — all meaning "nothing to do".
class NameUnchanged extends NameValidation {
  const NameUnchanged();
}

/// Validate a rename/create input. [current] is the existing name for a
/// rename, or `null` for create; returning [NameUnchanged] for equal
/// values lets the caller short-circuit silently.
NameValidation validateFileName(String? raw, {String? current}) {
  if (raw == null) return const NameUnchanged();
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const NameUnchanged();
  if (current != null && trimmed == current) return const NameUnchanged();
  if (trimmed.contains('/') || trimmed.contains('\\')) {
    return NameInvalid(ambientL10n.filesNameInvalidChars);
  }
  if (trimmed == '.' || trimmed == '..') {
    return NameInvalid(ambientL10n.filesNameInvalid);
  }
  return NameOk(trimmed);
}
