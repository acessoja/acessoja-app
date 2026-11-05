enum PasswordStrengthLevel { veryWeak, weak, fair, good, strong }

class PasswordStrengthResult {
  const PasswordStrengthResult(this.level, this.score);

  final PasswordStrengthLevel level;
  final int score;
}

/// Small local, pattern-aware estimator for progressive feedback only.
/// Django validators remain authoritative when the account is submitted.
PasswordStrengthResult assessPasswordStrength(String password) {
  if (password.isEmpty) {
    return const PasswordStrengthResult(PasswordStrengthLevel.veryWeak, 0);
  }

  final folded = password.toLowerCase();
  final common = {
    'password',
    'password123',
    'senha',
    'senha123',
    '12345678',
    'qwerty',
    'letmein',
    'welcome',
    'admin',
    'abc123',
  };
  final repeated = RegExp(r'^(.)\1+$').hasMatch(password);
  final sequential = RegExp(
    r'(0123|1234|2345|3456|4567|5678|6789|abcd|qwer)',
  ).hasMatch(folded);

  var score = 0;
  if (password.runes.length >= 8) score++;
  if (password.runes.length >= 12) score++;
  if (password.runes.length >= 16) score++;
  if (password.runes.length >= 20 || password.contains(' ')) score++;
  if (password.runes.toSet().length >= 8) score++;
  if (common.contains(folded) || repeated || sequential) score = 1;
  score = score.clamp(0, 4).toInt();

  final level = switch (score) {
    0 => PasswordStrengthLevel.veryWeak,
    1 => PasswordStrengthLevel.weak,
    2 => PasswordStrengthLevel.fair,
    3 => PasswordStrengthLevel.good,
    _ => PasswordStrengthLevel.strong,
  };
  return PasswordStrengthResult(level, score);
}
