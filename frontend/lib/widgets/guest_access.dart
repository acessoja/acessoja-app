import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/account_strings.dart';

/// Context for a public visitor who opens an account-only action.
class GuestAccess extends StatelessWidget {
  const GuestAccess({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onLogin,
    required this.onRegister,
    required this.onExplore,
  });

  final IconData icon;
  final String title, description;
  final VoidCallback onLogin, onRegister, onExplore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, size: 36, color: colors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onLogin,
                  child: Text(
                    accountText(context, 'Entrar na minha conta', 'Sign in'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onRegister,
                  child: Text(
                    accountText(
                      context,
                      'Criar uma conta',
                      'Create an account',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onExplore,
                  child: Text(
                    accountText(
                      context,
                      'Continuar explorando',
                      'Keep exploring',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
