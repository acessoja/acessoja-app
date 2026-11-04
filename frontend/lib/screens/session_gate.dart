import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_http.dart';
import '../services/auth_session_controller.dart';
import '../l10n/account_strings.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.bootstrap});
  final Future<void> bootstrap;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _starting = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await widget.bootstrap;
      if (mounted) setState(() => _starting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSessionController>();
    if (!_starting && session.authenticated) {
      return Column(
        children: [
          if (session.warning == null)
            const SizedBox.shrink()
          else
            MaterialBanner(
              content: Semantics(
                liveRegion: true,
                child: Text(
                  accountText(
                    context,
                    'Não foi possível confirmar o armazenamento seguro da sessão. Pode ser necessário entrar novamente.',
                    'Secure session storage could not be confirmed. You may need to sign in again.',
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => session.warning = null,
                  child: Text(accountText(context, 'Entendi', 'OK')),
                ),
              ],
            ),
          Expanded(child: MainScreen(userName: session.userName!)),
        ],
      );
    }
    if (_starting || session.status == AuthStatus.initializing) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: accountText(
              context,
              'Validando sessão',
              'Validating session',
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (session.status == AuthStatus.offlineRetry) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accountText(
                  context,
                  'Não foi possível validar a sessão.',
                  'Unable to validate the session.',
                ),
              ),
              TextButton(
                onPressed: AppHttp.restoreSession,
                child: Text(
                  accountText(context, 'Tentar novamente', 'Try again'),
                ),
              ),
              TextButton(
                onPressed: AppHttp.clearSession,
                child: Text(
                  accountText(context, 'Voltar ao login', 'Back to login'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return LoginScreen(onLoginSuccess: (_, __) {});
  }
}
