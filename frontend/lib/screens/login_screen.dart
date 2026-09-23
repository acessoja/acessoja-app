import '../widgets/preference_controls.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'register_screen.dart';

/// Tela de autenticação do AcessoJá.
///
/// A interface foi reorganizada visualmente, mas a superfície pública e o
/// fluxo original foram preservados:
/// - [apiService] continua permitindo mocks nos testes;
/// - [onLoginSuccess] continua permitindo controlar a navegação nos testes;
/// - o login continua sendo realizado pelo [ApiService];
/// - o cadastro continua abrindo [RegisterScreen];
/// - o login bem-sucedido continua abrindo [MainScreen].
class LoginScreen extends StatefulWidget {
  /// Serviço usado para autenticar o usuário.
  /// Em produção usa [HttpApiService]; nos testes pode receber um mock.
  final ApiService? apiService;

  /// Permite controlar, em testes, o que acontece após um login
  /// bem-sucedido, evitando navegar para a [MainScreen] real.
  final void Function(BuildContext context, Map<String, dynamic> user)?
      onLoginSuccess;

  const LoginScreen({super.key, this.apiService, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends SafeState<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  late final ApiService _apiService = widget.apiService ?? HttpApiService();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // A lógica de autenticação permanece preservada.
  Future<void> _login(BuildContext context) async {
    if (_isSubmitting) return;
    final nome = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (nome.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.requiredFields)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.login(nome: nome, password: password);
      if (!context.mounted) {
        return;
      }

      if (result.success) {
        final user = result.user ?? <String, dynamic>{};

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(context, user);
          return;
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MainScreen(
              userName: user['nome'],
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 0.08);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;

              final tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

              return FadeTransition(
                opacity: animation.drive(fadeTween),
                child: SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.apiMessage(result.message,
                fallback: context.l10n.invalidCredentials)),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.connectionError)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSocialLoginMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.socialUnavailable(provider)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(actions: const [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const LanguageSelector())
      ]),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Semantics(
                        image: true,
                        label: context.l10n.logo,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AcessoJá',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.accessAccount,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.l10n.signIn,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.signInHint,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildInputField(
                              controller: _userController,
                              label: context.l10n.user,
                              hint: context.l10n.usernameHint,
                              icon: Icons.person_outline_rounded,
                              primaryColor: colors.primary,
                              textColor: colors.text,
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              controller: _passwordController,
                              label: context.l10n.password,
                              hint: context.l10n.passwordHint,
                              icon: Icons.lock_outline_rounded,
                              obscure: true,
                              primaryColor: colors.primary,
                              textColor: colors.text,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                        content:
                                            Text(context.l10n.passwordHelp))),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.primaryDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.forgotPassword,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _login(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.onPrimary))
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            context.l10n.signIn,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 19),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              context.l10n.continueWith,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSocialButton(
                                    label: 'Google',
                                    glyph: 'G',
                                    glyphColor: const Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSocialButton(
                                    label: 'Apple',
                                    glyph: '',
                                    glyphColor: colors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.primaryDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    text: context.l10n.noAccount,
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: context.l10n.signUpLink,
                                        style: TextStyle(
                                          color: colors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String glyph,
    required Color glyphColor,
  }) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: context.l10n.socialUnavailable(label),
        child: OutlinedButton(
          onPressed: () => _showSocialLoginMessage(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: colors.surface,
            foregroundColor: colors.text,
            side: BorderSide(color: colors.border, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label == 'Apple')
                Icon(Icons.apple, color: glyphColor, size: 21)
              else
                Text(
                  glyph,
                  style: TextStyle(
                    color: glyphColor,
                    fontSize: label == 'Apple' ? 21 : 19,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    required Color textColor,
    bool obscure = false,
  }) {
    final colors = AppColors.of(context);

    return Semantics(
      textField: true,
      label: label,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofillHints: [
          obscure ? AutofillHints.password : AutofillHints.username
        ],
        textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
        onSubmitted: obscure ? (_) => _login(context) : null,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.muted,
            fontSize: 14,
          ),
          labelStyle: TextStyle(
            color: colors.muted,
            fontSize: 14,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: primaryColor, size: 21),
          filled: true,
          fillColor: colors.fieldBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
