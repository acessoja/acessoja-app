import 'package:flutter/material.dart';

import '../services/places_service.dart';

/// Confirma nome/endereço e autentica somente esta escrita. A senha não é
/// persistida nem enviada para OSM; coordenadas vêm do token assinado da API.
class ExternalPlaceRegistration extends StatefulWidget {
  final Map<String, dynamic> place;
  final String userName;
  const ExternalPlaceRegistration({super.key, required this.place,
    required this.userName});

  @override
  State<ExternalPlaceRegistration> createState() => _RegistrationState();
}

class _RegistrationState extends State<ExternalPlaceRegistration> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.place['nome']?.toString());
  late final _address = TextEditingController(text: widget.place['endereco']?.toString());
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final local = await const PlacesService().importExternalPlace(
        place: widget.place, name: _name.text, address: _address.text,
        userName: widget.userName, password: _password.text,
      );
      _password.clear();
      if (mounted) {
        Navigator.pop(context, local);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is PlacesException
          ? error.message : 'Cadastro indisponível. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Preencha este campo.' : null;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Contribuir com o AcessoJá'),
      content: SingleChildScrollView(
        child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Confirme os dados do OpenStreetMap. A acessibilidade '
              'será informada no fluxo de avaliação do local, após iniciar uma rota.'),
            const SizedBox(height: 12),
            TextFormField(controller: _name, maxLength: 255,
              enabled: !_saving, validator: _required,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nome do local')),
            TextFormField(controller: _address, maxLength: 255,
              enabled: !_saving, validator: _required,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Endereço')),
            TextFormField(controller: _password, obscureText: true,
              enabled: !_saving, validator: _required,
              autocorrect: false, enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Confirme sua senha'),
              onFieldSubmitted: (_) => _submit()),
            if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          ])),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Confirmando cadastro…' : 'Confirmar cadastro')),
      ],
    ),
  );
}
