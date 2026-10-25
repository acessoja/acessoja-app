import 'package:flutter/material.dart';
import '../l10n/account_strings.dart';

class AccountIdentityDialog extends StatefulWidget {
  const AccountIdentityDialog(
      {super.key, required this.deleting, this.emailChange = false});
  final bool deleting;
  final bool emailChange;
  @override
  State<AccountIdentityDialog> createState() => _AccountIdentityDialogState();
}

class _AccountIdentityDialogState extends State<AccountIdentityDialog> {
  final _password = TextEditingController();
  bool _confirmed = false, _visible = false;
  String t(String pt, String en) => accountText(context, pt, en);
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(widget.deleting
            ? t('Confirmar exclusão', 'Confirm deletion')
            : t('Confirmar identidade', 'Confirm identity')),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.deleting
                  ? t('Esta ação não pode ser desfeita no aplicativo. Exporte seus dados antes, se desejar. Confirme sua senha atual e a exclusão. Cópias privadas expiram conforme o aviso e exclusões são reaplicadas antes de restaurar backups.',
                      'This action cannot be undone in the app. Export first if you wish. Confirm your current password and deletion. Private copies expire under the notice and deletions are reapplied before backups are restored.')
                  : widget.emailChange
                      ? t('Confirme sua senha atual para alterar o e-mail de recuperação.',
                          'Confirm your current password to change your recovery email.')
                      : t('Confirme sua senha atual para baixar seus dados. A senha é usada apenas nesta solicitação.',
                          'Confirm your current password to download your data. The password is used only for this request.')),
              const SizedBox(height: 16),
              TextField(
                  controller: _password,
                  autofocus: true,
                  obscureText: !_visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: t('Senha atual', 'Current password'),
                      suffixIcon: IconButton(
                          tooltip: _visible
                              ? t('Ocultar senha', 'Hide password')
                              : t('Mostrar senha', 'Show password'),
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(_visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined)))),
              if (widget.deleting)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _confirmed,
                    onChanged: (value) =>
                        setState(() => _confirmed = value == true),
                    title: Text(t('Quero excluir minha conta e meus dados.',
                        'I want to delete my account and data.'))),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Cancelar', 'Cancel'))),
          TextButton(
              onPressed:
                  _password.text.isEmpty || (widget.deleting && !_confirmed)
                      ? null
                      : () => Navigator.pop(context, _password.text),
              child: Text(widget.deleting
                  ? t('Confirmar exclusão', 'Confirm deletion')
                  : widget.emailChange
                      ? t('Confirmar', 'Confirm')
                      : t('Exportar', 'Export')))
        ],
      );
}
