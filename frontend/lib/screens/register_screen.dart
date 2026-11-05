import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../config.dart';
import '../l10n/account_strings.dart';
import '../l10n/strings.dart';
import '../services/app_http.dart';
import '../services/password_strength.dart';
import '../widgets/preference_controls.dart';
import '../widgets/safe_state.dart';

enum _FieldState { untouched, editing, verifying, valid, invalid, network }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends SafeState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final Map<String, _FieldState> _states = {
    'nome': _FieldState.untouched,
    'email': _FieldState.untouched,
    'password': _FieldState.untouched,
    'confirm': _FieldState.untouched,
  };
  final Map<String, String> _messages = {};
  Timer? _nameTimer;
  int _nameGeneration = 0;
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _submitted = false;
  String? _formMessage;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => _onBlur('nome', _nameFocus));
    _emailFocus.addListener(() => _onBlur('email', _emailFocus));
    _passwordFocus.addListener(() => _onBlur('password', _passwordFocus));
    _confirmFocus.addListener(() => _onBlur('confirm', _confirmFocus));
  }

  @override
  void dispose() {
    _nameTimer?.cancel();
    for (final controller in [
      _nameController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      controller.dispose();
    }
    for (final focus in [
      _nameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      focus.dispose();
    }
    super.dispose();
  }

  String _text(String pt, String en) => accountText(context, pt, en);

  String? _validateName(String value) {
    if (value.isEmpty) {
      return _text('Informe um nome de usuário.', 'Enter a username.');
    }
    if (!RegExp(r'^[A-Za-z0-9À-ÖØ-öø-ÿ._-]{3,30}$').hasMatch(value)) {
      return _text(
        'Use 3–30 letras, números, ponto, _ ou hífen.',
        'Use 3–30 letters, numbers, dot, _ or hyphen.',
      );
    }
    if ({
      'admin',
      'administrator',
      'root',
      'support',
      'suporte',
      'acessoja',
      'moderador',
    }.contains(value.toLowerCase())) {
      return _text(
        'Este nome reservado não pode ser usado.',
        'This reserved name cannot be used.',
      );
    }
    return null;
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) {
      return _text('Informe um e-mail.', 'Enter an email address.');
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
        ? null
        : context.l10n.invalidEmail;
  }

  String? _validatePassword(String value) => value.isEmpty
      ? _text('Informe uma senha.', 'Enter a password.')
      : value.runes.length < 8
      ? _text('Use pelo menos 8 caracteres.', 'Use at least 8 characters.')
      : null;

  String? _validateConfirm(String value) => value.isEmpty
      ? _text('Confirme sua senha.', 'Confirm your password.')
      : value != _passwordController.text
      ? context.l10n.passwordMismatch
      : null;

  String _value(String field) => switch (field) {
    'nome' => _nameController.text,
    'email' => _emailController.text.trim(),
    'password' => _passwordController.text,
    _ => _confirmPasswordController.text,
  };

  void _onBlur(String field, FocusNode node) {
    if (node.hasFocus) return;
    if (field == 'nome') {
      _scheduleNameAvailability(immediate: true);
    } else {
      _validateField(field, showEmpty: _submitted);
    }
  }

  void _validateField(String field, {bool showEmpty = false}) {
    final value = _value(field);
    final error = switch (field) {
      'email' => _validateEmail(value),
      'password' => _validatePassword(value),
      _ => _validateConfirm(value),
    };
    if (!showEmpty && value.isEmpty && !_submitted) {
      setState(() {
        _states[field] = _FieldState.untouched;
        _messages.remove(field);
      });
      return;
    }
    setState(() {
      _states[field] = error == null ? _FieldState.valid : _FieldState.invalid;
      _messages[field] =
          error ??
          (field == 'email'
              ? _text('Formato de e-mail válido.', 'Valid email format.')
              : _text('As senhas coincidem.', 'Passwords match.'));
    });
  }

  void _onNameChanged(String value) {
    _nameGeneration++;
    _nameTimer?.cancel();
    _suggestions = const [];
    final error = _validateName(value);
    if (error != null) {
      setState(() {
        _states['nome'] = value.isEmpty
            ? _FieldState.untouched
            : _FieldState.editing;
        _messages.remove('nome');
      });
      return;
    }
    setState(() {
      _states['nome'] = _FieldState.verifying;
      _messages['nome'] = _text('Verificando…', 'Checking…');
    });
    _scheduleNameAvailability();
  }

  void _scheduleNameAvailability({bool immediate = false}) {
    _nameTimer?.cancel();
    final value = _nameController.text;
    if (_validateName(value) != null) return;
    final generation = _nameGeneration;
    _nameTimer = Timer(
      Duration(milliseconds: immediate ? 0 : 600),
      () => _checkNameAvailability(value, generation),
    );
  }

  Future<void> _checkNameAvailability(String value, int generation) async {
    try {
      final uri = Uri.parse(
        '${Config.baseUrl}/auth/username-availability/',
      ).replace(queryParameters: {'nome': value});
      final response = await AppHttp.getPublic(uri);
      if (!mounted ||
          generation != _nameGeneration ||
          _nameController.text != value) {
        return;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data is Map) {
        final available = data['available'] == true;
        setState(() {
          _states['nome'] = available ? _FieldState.valid : _FieldState.invalid;
          _messages['nome'] = available
              ? _text('Nome disponível.', 'Username available.')
              : _text(
                  'Este nome já está em uso.',
                  'This username is already in use.',
                );
          _suggestions = available
              ? const []
              : List<String>.from(data['suggestions'] ?? const []);
        });
      } else {
        _setNameNetworkError();
      }
    } catch (_) {
      if (mounted && generation == _nameGeneration) _setNameNetworkError();
    }
  }

  void _setNameNetworkError() => setState(() {
    _states['nome'] = _FieldState.network;
    _messages['nome'] = _text(
      'Não foi possível verificar agora.',
      'Could not verify right now.',
    );
  });

  void _onTextChanged(String field, String value) {
    if (field == 'nome') return _onNameChanged(value);
    setState(() {
      _states[field] = value.isEmpty
          ? _FieldState.untouched
          : _FieldState.editing;
      _messages.remove(field);
      _formMessage = null;
    });
    if (_submitted || field == 'email') _validateField(field);
    if (field == 'password' && _confirmPasswordController.text.isNotEmpty) {
      _validateField('confirm');
    }
  }

  bool _validateAll() {
    _submitted = true;
    _validateField('email', showEmpty: true);
    _validateField('password', showEmpty: true);
    _validateField('confirm', showEmpty: true);
    final nameError = _validateName(_nameController.text);
    if (nameError != null) {
      setState(() {
        _states['nome'] = _FieldState.invalid;
        _messages['nome'] = nameError;
      });
    } else if (_states['nome'] != _FieldState.valid) {
      _scheduleNameAvailability(immediate: true);
      setState(() => _messages['nome'] = _text('Verificando…', 'Checking…'));
    }
    final valid =
        _states['email'] == _FieldState.valid &&
        _states['password'] == _FieldState.valid &&
        _states['confirm'] == _FieldState.valid &&
        _states['nome'] == _FieldState.valid;
    if (!valid) _focusFirstInvalid();
    return valid;
  }

  void _focusFirstInvalid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      (_states['nome'] != _FieldState.valid
              ? _nameFocus
              : _states['email'] != _FieldState.valid
              ? _emailFocus
              : _states['password'] != _FieldState.valid
              ? _passwordFocus
              : _confirmFocus)
          .requestFocus();
    });
  }

  Future<void> _register(BuildContext context) async {
    if (_isSubmitting || !_validateAll()) return;
    setState(() => _isSubmitting = true);
    try {
      final response = await AppHttp.postPublic(
        Uri.parse('${Config.baseUrl}/auth/users/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _nameController.text,
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      if (!context.mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.accountCreated)));
        Navigator.pop(context);
      } else {
        _mapApiErrors(response);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.connectionError)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _mapApiErrors(dynamic response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode == 429 || response.statusCode >= 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['detail']?.toString() ??
                _text(
                  'Serviço temporariamente indisponível.',
                  'Service temporarily unavailable.',
                ),
          ),
        ),
      );
      return;
    }
    final errors = <String, dynamic>{...data};
    final nonField =
        errors.remove('non_field_errors') ?? errors.remove('detail');
    for (final entry in errors.entries) {
      final field = entry.key == 're_password' ? 'confirm' : entry.key;
      if (!_states.containsKey(field)) continue;
      final message = entry.value is List
          ? (entry.value as List).join(' ')
          : entry.value.toString();
      setState(() {
        _states[field] = _FieldState.invalid;
        _messages[field] = message;
      });
    }
    if (nonField != null) {
      setState(
        () => _formMessage = nonField is List
            ? nonField.join(' ')
            : nonField.toString(),
      );
    }
    _focusFirstInvalid();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        actions: const [LanguageSelector()],
        backgroundColor: colors.pageBackground,
        elevation: 0,
        title: Text(
          context.l10n.createAccount,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    children: [
                      Semantics(
                        image: true,
                        label: context.l10n.logo,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 68,
                          height: 68,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.createYourAccount,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.registerIntro,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Container(
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
                              context.l10n.accountData,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.registerDetails,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              'nome',
                              _nameController,
                              _nameFocus,
                              context.l10n.registerName,
                              context.l10n.registerNameHint,
                              Icons.person_outline_rounded,
                              _onNameChanged,
                            ),
                            if (_suggestions.isNotEmpty)
                              _buildSuggestions(colors),
                            const SizedBox(height: 12),
                            _buildField(
                              'email',
                              _emailController,
                              _emailFocus,
                              context.l10n.registerEmail,
                              context.l10n.emailHint,
                              Icons.email_outlined,
                              (v) => _onTextChanged('email', v),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              'password',
                              _passwordController,
                              _passwordFocus,
                              context.l10n.password,
                              context.l10n.passwordHint,
                              Icons.lock_outline_rounded,
                              (v) => _onTextChanged('password', v),
                              obscure: true,
                            ),
                            if (_passwordController.text.isNotEmpty)
                              _buildStrength(colors),
                            const SizedBox(height: 12),
                            _buildField(
                              'confirm',
                              _confirmPasswordController,
                              _confirmFocus,
                              context.l10n.confirmPassword,
                              context.l10n.repeatPassword,
                              Icons.verified_user_outlined,
                              (v) => _onTextChanged('confirm', v),
                              obscure: true,
                              action: TextInputAction.done,
                              onSubmitted: (_) => _register(context),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              label: Text(
                                _text(
                                  _showPassword
                                      ? 'Ocultar senha'
                                      : 'Mostrar senha',
                                  _showPassword
                                      ? 'Hide password'
                                      : 'Show password',
                                ),
                              ),
                            ),
                            if (_formMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _formMessage!,
                                  style: TextStyle(
                                    color: colors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Semantics(
                              button: true,
                              enabled: !_isSubmitting,
                              label: _isSubmitting
                                  ? context.l10n.working
                                  : context.l10n.register,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _register(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            context.l10n.register,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 19,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.registerFooter,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 12),
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

  Widget _buildField(
    String field,
    TextEditingController controller,
    FocusNode focus,
    String label,
    String hint,
    IconData icon,
    ValueChanged<String> onChanged, {
    TextInputType? keyboardType,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = AppColors.of(context);
    final state = _states[field]!;
    final hasStatus =
        state != _FieldState.untouched && state != _FieldState.editing;
    final statusColor = state == _FieldState.valid
        ? colors.success
        : state == _FieldState.network
        ? colors.warning
        : colors.danger;
    final statusIcon = state == _FieldState.verifying
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            state == _FieldState.valid ? Icons.check : Icons.close,
            color: statusColor,
            size: 20,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          textField: true,
          label: label,
          child: TextField(
            controller: controller,
            focusNode: focus,
            keyboardType: keyboardType,
            obscureText: obscure && !_showPassword,
            autofillHints: [
              obscure
                  ? AutofillHints.newPassword
                  : field == 'email'
                  ? AutofillHints.email
                  : AutofillHints.newUsername,
            ],
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: action,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: colors.muted),
              suffixIcon: hasStatus
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: statusIcon,
                    )
                  : null,
              filled: true,
              fillColor: colors.fieldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasStatus ? statusColor : colors.muted,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasStatus ? statusColor : colors.primary,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: hasStatus && (_messages[field]?.isNotEmpty ?? false)
              ? Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          state == _FieldState.valid
                              ? Icons.check_circle
                              : state == _FieldState.network
                              ? Icons.info
                              : Icons.error,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _messages[field]!,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSuggestions(AppColors colors) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(
      spacing: 6,
      children: [
        Text(
          _text('Alternativas para tentar:', 'Alternatives to try:'),
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
        ..._suggestions.map(
          (suggestion) => ActionChip(
            label: Text(suggestion),
            onPressed: () {
              _nameController.text = suggestion;
              _nameController.selection = TextSelection.collapsed(
                offset: suggestion.length,
              );
              _onNameChanged(suggestion);
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildStrength(AppColors colors) {
    final result = assessPasswordStrength(_passwordController.text);
    final label = switch (result.level) {
      PasswordStrengthLevel.veryWeak => _text(
        'Senha muito fraca',
        'Very weak password',
      ),
      PasswordStrengthLevel.weak => _text('Senha fraca', 'Weak password'),
      PasswordStrengthLevel.fair => _text('Senha razoável', 'Fair password'),
      PasswordStrengthLevel.good => _text('Senha boa', 'Good password'),
      PasswordStrengthLevel.strong => _text('Senha forte', 'Strong password'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: index < result.score ? colors.success : colors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            label,
            style: TextStyle(
              color: colors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _text(
            'Pelo menos 8 caracteres; frases maiores e difíceis de adivinhar protegem melhor sua conta.',
            'At least 8 characters; longer, harder-to-guess phrases better protect your account.',
          ),
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
