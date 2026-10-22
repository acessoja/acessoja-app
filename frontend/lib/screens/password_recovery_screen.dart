import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';
import '../services/account_service.dart';
import '../widgets/settings_page.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen(
      {super.key,
      this.link,
      this.invalidLink = false,
      this.service = const AccountService()});
  final PasswordResetLink? link;
  final bool invalidLink;
  final AccountService service;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeated = TextEditingController();
  final _errorFocus = FocusNode();
  bool _busy = false, _done = false, _visible = false;
  String? _error;
  bool get _confirming => widget.link != null;
  String t(String pt, String en) => accountText(context, pt, en);
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repeated.dispose();
    _errorFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_confirming) {
        await widget.service
            .confirmReset(widget.link!, _password.text, _repeated.text);
      } else {
        await widget.service.requestReset(_email.text);
      }
      _password.clear();
      _repeated.clear();
      _email.clear();
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is AccountException && error.status == 429) {
          _error = t('Muitas tentativas. Aguarde e tente novamente.',
              'Too many attempts. Please wait and try again.');
        } else if (error is AccountException &&
            error.passwordErrors.isNotEmpty) {
          _error = error.passwordErrors.join('\n');
        } else if (error is AccountException &&
            error.status == 400 &&
            _confirming) {
          _error = t(
              'Link inválido, expirado ou já utilizado. Solicite outro link.',
              'This link is invalid, expired or already used. Request a new one.');
        } else if (error is AccountException && error.status == 400) {
          _error =
              t('Confira o endereço de e-mail.', 'Check the email address.');
        } else {
          _error = t(
              'Não foi possível concluir agora. Verifique sua conexão e tente novamente.',
              'Unable to complete this request. Check your connection and try again.');
        }
      });
      _errorFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);

  Widget _message(String message) => Semantics(
      liveRegion: true,
      child: Focus(focusNode: _errorFocus, child: Text(message)));

  @override
  Widget build(BuildContext context) {
    final title = t('Recuperar acesso', 'Recover access');
    return SettingsPage(
        title: title,
        notice: _error == null ? null : _message(_error!),
        children: [
          Text(
              _confirming
                  ? t('Escolha uma nova senha', 'Choose a new password')
                  : t('Esqueci minha senha', 'Forgot my password'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (widget.invalidLink) ...[
            _message(t(
                'Este link não é válido. Solicite um novo e-mail de recuperação.',
                'This link is invalid. Request a new recovery email.')),
          ] else if (_done) ...[
            _message(_confirming
                ? t('Senha alterada. Suas sessões anteriores foram encerradas. Entre com a nova senha.',
                    'Password changed. Previous sessions have ended. Sign in with your new password.')
                : t('Se houver uma conta elegível para este e-mail, enviaremos as instruções. Confira também a pasta de spam.',
                    'If an eligible account exists for this email, we will send instructions. Check your spam folder too.')),
          ] else ...[
            Text(_confirming
                ? t('Use pelo menos 8 caracteres. Evite senhas comuns, apenas números e informações do seu perfil.',
                    'Use at least 8 characters. Avoid common passwords, only numbers and your profile information.')
                : t('Informe o e-mail da sua conta. Você poderá concluir a recuperação no navegador, inclusive pelo celular.',
                    'Enter your account email. You can complete recovery in your browser, including on your phone.')),
            const SizedBox(height: 20),
            Form(
                key: _form,
                child: AutofillGroup(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_confirming)
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                            labelText: t('E-mail da conta', 'Account email')),
                        validator: (value) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(value?.trim() ?? '')
                                ? null
                                : t('Informe um e-mail válido.',
                                    'Enter a valid email address.'),
                      ),
                    if (_confirming) ...[
                      TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          autofocus: true,
                          obscureText: !_visible,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: t('Nova senha', 'New password'),
                              suffixIcon: IconButton(
                                  tooltip: _visible
                                      ? t('Ocultar senha', 'Hide password')
                                      : t('Mostrar senha', 'Show password'),
                                  onPressed: () =>
                                      setState(() => _visible = !_visible),
                                  icon: Icon(_visible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined))),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? t('Use pelo menos 8 caracteres.',
                                  'Use at least 8 characters.')
                              : null),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _repeated,
                          enabled: !_busy,
                          obscureText: !_visible,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                              labelText: t('Confirmar nova senha',
                                  'Confirm new password')),
                          validator: (value) => value != _password.text
                              ? t('As senhas não coincidem.',
                                  'Passwords do not match.')
                              : null),
                    ],
                    const SizedBox(height: 20),
                    if (_busy) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                        child: Text(_busy
                            ? t('Aguarde…', 'Please wait…')
                            : _confirming
                                ? t('Salvar nova senha', 'Save new password')
                                : t('Solicitar instruções',
                                    'Request instructions'))),
                  ],
                ))),
          ],
          if (widget.invalidLink || (_confirming && !_done))
            TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                            builder: (_) => const PasswordRecoveryScreen())),
                child: Text(t('Solicitar outro link', 'Request another link'))),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _busy ? null : _login,
              child: Text(t('Voltar para entrar', 'Back to sign in'))),
        ]);
  }
}
