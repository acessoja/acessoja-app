import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';
import '../services/account_service.dart';
import '../services/app_http.dart';
import '../services/personal_data_download.dart';
import '../services/route_history_service.dart';
import '../widgets/settings_page.dart';
import '../widgets/account_identity_dialog.dart';
import 'privacidade_screen.dart';
import 'route_history_screen.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen(
      {super.key,
      required this.userName,
      this.service = const AccountService(),
      this.history = const RouteHistoryService(),
      this.download = savePersonalData});
  final String userName;
  final AccountService service;
  final RouteHistoryService history;
  final Future<bool> Function(Uint8List) download;
  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  Map<String, dynamic>? _document;
  bool _loading = true, _busy = false, _expired = false;
  String? _message;
  int _request = 0;
  String t(String pt, String en) => accountText(context, pt, en);
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    _request++;
    setState(() {
      _document = null;
      _expired = true;
      _busy = false;
      _loading = false;
      _message = null;
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final data = await widget.service.privacy();
      if (mounted && request == _request && !_expired) {
        setState(() => _document = data);
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _message = _error(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  String _error(Object error) {
    if (error is AccountException && error.status == 401) {
      return t('Sua sessão terminou. Entre novamente.',
          'Your session ended. Sign in again.');
    }
    if (error is AccountException && error.status == 400) {
      return t(
          'Confira sua senha atual. Se o arquivo for muito grande, solicite uma exportação assistida ao contato de privacidade.',
          'Check your current password. For large files, ask the privacy contact for an assisted export.');
    }
    if (error is AccountException && error.status == 429) {
      return t('Muitas tentativas. Aguarde antes de tentar novamente.',
          'Too many attempts. Please wait before trying again.');
    }
    return t(
        'Não foi possível concluir. Tente novamente. Nenhuma confirmação de conclusão foi recebida.',
        'Unable to complete this request. Try again. No completion was confirmed.');
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy || _expired) return;
    final session = AppHttp.sessionRevision.value;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted && session == AppHttp.sessionRevision.value) {
        setState(() => _message = _error(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(String purpose, bool value) => _run(() async {
        await widget.history.savePreferences(
            enabled: purpose == 'route_history' ? value : null,
            origin: purpose == 'route_origin' ? value : null,
            noticeVersion: _document?['notice_version'] as String?);
        final data = await widget.service.privacy();
        if (mounted && !_expired) {
          setState(() {
            _document = data;
            _message = t('Escolha confirmada pelo servidor.',
                'Your choice was confirmed by the server.');
          });
        }
      });

  Future<void> _eraseHistory({bool originsOnly = false}) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: Text(t(
                  'Apagar dados já guardados?', 'Erase data already stored?')),
              content: Text(originsOnly
                  ? t('Remove as origens salvas. Os destinos continuam no seu histórico.',
                      'Removes saved origins. Destinations remain in your history.')
                  : t('Apaga seu histórico de rotas. Não apaga avaliações, favoritos ou estabelecimentos.',
                      'Erases route history. Reviews, favorites and establishments are kept.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t('Cancelar', 'Cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('Apagar', 'Erase')))
              ],
            ));
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.history.clear(originsOnly: originsOnly);
      if (mounted && !_expired) {
        setState(() => _message = t('Remoção confirmada pelo servidor.',
            'Erasure confirmed by the server.'));
      }
    });
  }

  Future<void> _export() async {
    final password = await showDialog<String>(
        context: context,
        builder: (_) => const AccountIdentityDialog(deleting: false));
    if (password == null || !mounted) return;
    await _run(() async {
      final bytes = await widget.service.export(password);
      try {
        if (!mounted || _expired) return;
        final saved = await widget.download(bytes);
        if (mounted && !_expired) {
          setState(() => _message = saved
              ? t('Download ou salvamento solicitado. Confira o destino escolhido e guarde o arquivo em local privado.',
                  'Download or save requested. Check your chosen destination and keep the file private.')
              : t('Salvamento cancelado.', 'Save cancelled.'));
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    });
  }

  Future<void> _delete() async {
    final password = await showDialog<String>(
        context: context,
        builder: (_) => const AccountIdentityDialog(deleting: true));
    if (password == null || !mounted) return;
    await _run(() async {
      final published = await widget.service.delete(password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
              builder: (_) => _AccountDeletionResult(published: published)),
          (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final choices =
        (_document?['choices'] as List? ?? []).whereType<Map>().toList();
    final history = choices.any((choice) =>
        choice['purpose'] == 'route_history' && choice['enabled'] == true);
    return PopScope(
        canPop: !_busy,
        child: SettingsPage(
          title: t('Privacidade e meus dados', 'Privacy and my data'),
          loading: _loading,
          notice: _message == null
              ? null
              : Semantics(liveRegion: true, child: Text(_message!)),
          children: [
            if (_expired) ...[
              Text(t(
                  'Sua sessão terminou. Os dados desta conta foram limpos da tela.',
                  'Your session ended. Account data was cleared from this screen.')),
              TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (_) => false),
                  child: Text(t('Entrar novamente', 'Sign in again'))),
            ] else if (_document == null) ...[
              TextButton(
                  onPressed: _load,
                  child: Text(t('Tentar novamente', 'Try again'))),
            ] else ...[
              Text(t('Você decide o que guardar', 'You choose what to keep'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(t(
                  'Não exigimos diagnóstico. Preferências de acessibilidade são privadas e opcionais. Autorizar GPS no dispositivo não autoriza guardar histórico. Perfil público não publica suas rotas ou sua posição.',
                  'No diagnosis is required. Accessibility preferences are private and optional. Device GPS permission does not authorize history storage. A public profile does not publish routes or your location.')),
              const SizedBox(height: 12),
              Text(
                  '${t('Versão do aviso', 'Notice version')}: ${_document!['notice_version']}'),
              const SizedBox(height: 20),
              if (_busy) const LinearProgressIndicator(),
              SettingsSection(
                  title: t('Escolhas opcionais', 'Optional choices'),
                  children: [
                    for (final choice in choices) ...[
                      SwitchListTile.adaptive(
                          value: choice['enabled'] == true,
                          onChanged: _busy ||
                                  (choice['purpose'] == 'route_origin' &&
                                      !history &&
                                      choice['enabled'] != true)
                              ? null
                              : (value) =>
                                  _change(choice['purpose'] as String, value),
                          title: Text(choice['purpose'] == 'route_history'
                              ? t('Guardar histórico de rotas',
                                  'Save route history')
                              : t('Guardar origem aproximada',
                                  'Save approximate origin')),
                          subtitle: Text(choice['purpose'] == 'route_history'
                              ? t('Guarda destinos, horários e estimativas das navegações iniciadas. Somente você pode consultar. Desligar impede novas gravações; os dados anteriores podem ser apagados abaixo.',
                                  'Saves destinations, times and estimates for started navigation. Only you can view them. Turning this off stops new records; erase previous data below.')
                              : t('Opcional, com histórico ativo. Guarda a origem arredondada para cerca de 1 km. É privada e não substitui a permissão de GPS.',
                                  'Optional, while history is active. Saves the origin rounded to about 1 km. It is private and separate from GPS permission.'))),
                      if (choice['legacy_choice'] == true)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(t(
                                'Havia uma escolha antiga sem registro deste aviso. Novas gravações estão pausadas até você confirmar sua escolha.',
                                'An earlier choice has no record of this notice. New collection is paused until you confirm your choice.'))),
                      if (choice['recorded_at'] != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                                '${t('Última decisão registrada', 'Last recorded decision')}: ${choice['recorded_at']}')),
                    ],
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _eraseHistory(originsOnly: true),
                        child: Text(t('Apagar origens já guardadas',
                            'Erase saved origins'))),
                    TextButton(
                        onPressed: _busy ? null : () => _eraseHistory(),
                        child: Text(t('Apagar histórico de rotas',
                            'Erase route history'))),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                            scrollable: true,
                                            title: Text(t(
                                                'Apagar visitas guardadas?',
                                                'Erase saved visits?')),
                                            content: Text(t(
                                                'Remove somente seus registros de chegada. Favoritos e avaliações permanecem.',
                                                'Only removes your arrival records. Favorites and reviews remain.')),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: Text(
                                                      t('Cancelar', 'Cancel'))),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: Text(
                                                      t('Apagar', 'Erase')))
                                            ]));
                                if (confirmed != true || !mounted) return;
                                await _run(() async {
                                  await widget.service.clearVisits();
                                  if (mounted && !_expired) {
                                    setState(() => _message = t(
                                        'Remoção confirmada pelo servidor.',
                                        'Erasure confirmed by the server.'));
                                  }
                                });
                              },
                        child: Text(t(
                            'Apagar visitas guardadas', 'Erase saved visits'))),
                    ListTile(
                        title: Text(
                            t('Consultar meu histórico', 'View my history')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const RouteHistoryScreen()))),
                  ]),
              ListTile(
                  title: Text(t('Visibilidade de perfil e avaliações',
                      'Profile and review visibility')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PrivacidadeScreen(
                                  userName: widget.userName)))),
              const SizedBox(height: 20),
              SettingsSection(
                  title: t('Exportar meus dados', 'Export my data'),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t(
                            'Baixe um JSON com seu perfil, preferências, favoritos, visitas, rotas, avaliações, contribuições, pontos e decisões registradas. Senhas e tokens não são incluídos. Logs, backups e dados de provedores externos exigem atendimento específico.',
                            'Download JSON with your profile, preferences, favorites, visits, routes, reviews, contributions, points and recorded choices. Passwords and tokens are excluded. Logs, backups and external-provider data need a separate request.'))),
                    TextButton(
                        onPressed: _busy ? null : _export,
                        child:
                            Text(t('Baixar meus dados', 'Download my data'))),
                  ]),
              SettingsSection(
                  title: t('Excluir minha conta', 'Delete my account'),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t(
                            'Você pode exportar antes de excluir. A exclusão remove seus dados da conta, avaliações e pontos e encerra suas sessões. Estabelecimentos compartilhados e dados de outras pessoas permanecem. Arquivos que você já baixou continuam sob seu controle.',
                            'You can export before deleting. Deletion removes account data, reviews and points and ends your sessions. Shared establishments and other people’s data remain. Files you downloaded stay under your control.'))),
                    OutlinedButton(
                        onPressed: _busy ? null : _delete,
                        child: Text(t('Excluir conta e dados',
                            'Delete account and data'))),
                  ]),
              Text(t(
                  'Logs mínimos ficam por até 14 dias; backups privados por até 14 dias. O registro técnico de exclusão fica por pelo menos 35 dias para impedir que dados excluídos voltem após uma restauração. Consentimentos anteriores são limitados a 180 dias, mantendo a decisão vigente.',
                  'Minimal logs are kept for up to 14 days; private backups for up to 14 days. A technical deletion receipt is kept for at least 35 days to prevent deleted data returning after restore. Earlier consent decisions are limited to 180 days, keeping the current decision.')),
              const SizedBox(height: 12),
              Text((_document!['contact_email'] as String? ?? '').isEmpty
                  ? t('Contato de privacidade indisponível neste ambiente.',
                      'The privacy contact is unavailable in this environment.')
                  : '${t('Contato de privacidade', 'Privacy contact')}: ${_document!['contact_email']}'),
            ],
          ],
        ));
  }
}

class _AccountDeletionResult extends StatelessWidget {
  const _AccountDeletionResult({required this.published});
  final bool published;
  @override
  Widget build(BuildContext context) => SettingsPage(
        title: accountText(
            context,
            published ? 'Conta excluída' : 'Exclusão em confirmação',
            published ? 'Account deleted' : 'Deletion confirmation pending'),
        children: [
          Semantics(
              liveRegion: true,
              child: Text(published
                  ? accountText(
                      context,
                      'Seus dados foram removidos do banco ativo e sua sessão foi encerrada. A proteção da exclusão será aplicada antes de liberar uma restauração de backup.',
                      'Your data was removed from the active database and your session ended. Deletion protection will be applied before a backup restore is released.')
                  : accountText(
                      context,
                      'Sua sessão foi encerrada e os dados foram removidos do banco ativo. A confirmação da proteção nos backups está pendente de atendimento operacional. A exclusão ainda não está totalmente confirmada.',
                      'Your session ended and data was removed from the active database. Backup protection is awaiting operational confirmation. Deletion is not yet fully confirmed.'))),
          TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (_) => false),
              child: Text(accountText(
                  context, 'Voltar para entrar', 'Back to sign in')))
        ],
      );
}
