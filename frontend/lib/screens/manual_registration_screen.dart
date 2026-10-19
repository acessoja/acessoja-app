import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/map_strings.dart';
import '../models/place_category.dart';
import '../services/app_http.dart';
import '../services/places_service.dart';
import '../services/review_changes.dart';
import 'login_screen.dart';
import 'map_point_picker.dart';

String manualRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ManualRegistrationScreen extends StatefulWidget {
  final LatLng? point;
  final PlacesService service;
  const ManualRegistrationScreen(
      {super.key, this.point, this.service = const PlacesService()});
  @override
  State<ManualRegistrationScreen> createState() => _ManualRegistrationState();
}

class _ManualRegistrationState extends State<ManualRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _address = TextEditingController(),
      _reason = TextEditingController();
  String? _category, _error;
  late LatLng? _point = widget.point;
  bool _confirmed = false, _saving = false;
  String _requestId = manualRequestId();
  Map<String, dynamic>? _payload;
  int? _owner, _ownerRevision;
  List<Map<String, dynamic>> _duplicates = [];
  bool get _uncertain => _payload != null;
  bool get _sameOwner => _owner == null
      ? _ownerRevision == AppHttp.sessionRevision.value
      : _owner == AppHttp.userId;
  String? _required(String? value) =>
      value == null || value.trim().isEmpty || value.trim().runes.length > 255
          ? context.mapText(
              'Preencha com até 255 caracteres.', 'Enter up to 255 characters.')
          : null;
  Future<bool> _login() async {
    if (AppHttp.authenticated && (!_uncertain || _sameOwner)) {
      return true;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LoginScreen(
                onLoginSuccess: (context, user) =>
                    Navigator.pop(context, true))));
    return mounted && AppHttp.authenticated && (!_uncertain || _sameOwner);
  }

  Future<void> _choose() async {
    final p = await Navigator.push<LatLng>(context,
        MaterialPageRoute(builder: (_) => MapPointPicker(initial: _point)));
    if (mounted && p != null) {
      setState(() {
        _point = p;
        _confirmed = true;
      });
    }
  }

  void _newDraft() {
    setState(() {
      _payload = null;
      _owner = null;
      _ownerRevision = null;
      _requestId = manualRequestId();
      _duplicates = [];
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    if (!_confirmed || _point == null || _category == null) {
      setState(() => _error = context.mapText(
          'Selecione categoria e confirme o ponto do local.',
          'Choose a category and confirm the place point.'));
      return;
    }
    if (!await _login() || !mounted) {
      return;
    }
    _payload ??= {
      'request_id': _requestId,
      'nome': _name.text.trim(),
      'endereco': _address.text.trim(),
      'categoria': _category,
      'latitude': _point!.latitude,
      'longitude': _point!.longitude,
      'point_confirmed': true,
      if (_reason.text.trim().isNotEmpty) 'distinct_reason': _reason.text.trim()
    };
    _owner ??= AppHttp.userId;
    _ownerRevision ??= AppHttp.sessionRevision.value;
    final session = AppHttp.sessionRevision.value;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final local = await widget.service.registerManual(Map.of(_payload!));
      if (!mounted || session != AppHttp.sessionRevision.value) {
        return;
      }
      reviewChanges.value++;
      Navigator.pop(context, local);
    } catch (error) {
      if (!mounted || session != AppHttp.sessionRevision.value) {
        return;
      }
      setState(() {
        if (error is ManualRegistrationException &&
            error.status == 409 &&
            error.data['candidates'] is List) {
          _duplicates = (error.data['candidates'] as List)
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
          _payload = null;
          _owner = null;
          _ownerRevision = null;
          _error = context.mapText(
              'Revise os possíveis duplicados. Para cadastrar outro local, justifique a diferença.',
              'Review possible duplicates. Explain the difference to register another place.');
        } else if (error is PlacesException &&
            (error.status == 400 || error.status == 401)) {
          _payload = null;
          _owner = null;
          _ownerRevision = null;
          if (error.status == 401) {
            AppHttp.clearSession();
          }
          _error = context.mapText(
              'Revise os dados ou entre novamente. O rascunho foi mantido.',
              'Check the fields or sign in again. Your draft was kept.');
        } else {
          _error = context.mapText(
              'Confirmação indisponível. Tente novamente com a mesma tentativa e conta.',
              'Confirmation unavailable. Retry the same request with the same account.');
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
          appBar: AppBar(
              title:
                  Text(context.mapText('Cadastrar local', 'Register place'))),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Text(context.mapText(
                        'Cadastre somente um estabelecimento ou local público identificado. A avaliação é opcional após salvar.',
                        'Register an identified establishment or public place. Reviewing is optional after saving.')),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _name,
                        enabled: !_saving && !_uncertain,
                        maxLength: 255,
                        validator: _required,
                        decoration: InputDecoration(
                            labelText: context.mapText(
                                'Nome do local', 'Place name'))),
                    TextFormField(
                        controller: _address,
                        enabled: !_saving && !_uncertain,
                        maxLength: 255,
                        validator: _required,
                        decoration: InputDecoration(
                            labelText: context.mapText('Endereço', 'Address'))),
                    DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText:
                                context.mapText('Categoria', 'Category')),
                        items: [
                          for (final entry in placeCategoryVisuals.entries)
                            DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                    context.mapText(entry.value.portuguese,
                                        entry.value.english),
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: _saving || _uncertain
                            ? null
                            : (v) => setState(() => _category = v)),
                    const SizedBox(height: 16),
                    Text(_point == null
                        ? context.mapText(
                            'Ponto não selecionado', 'Point not selected')
                        : '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}'),
                    OutlinedButton.icon(
                        onPressed: _saving || _uncertain ? null : _choose,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(context.mapText(
                            'Escolher ponto no mapa', 'Choose point on map'))),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _confirmed,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: _point == null || _saving || _uncertain
                            ? null
                            : (v) => setState(() => _confirmed = v == true),
                        title: Text(context.mapText(
                            'Confirmo que o estabelecimento está neste ponto.',
                            'I confirm the place is at this point.'))),
                    Text(context.mapText(
                        'Horário de funcionamento desconhecido. Nenhuma distância fixa será solicitada.',
                        'Opening hours unknown. No fixed distance is requested.')),
                    if (_duplicates.isNotEmpty) ...[
                      for (final local in _duplicates)
                        ListTile(
                            title: Text('${local['nome']}'),
                            subtitle: Text('${local['endereco']}'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => Navigator.pop(context, local)),
                      TextFormField(
                          controller: _reason,
                          enabled: !_saving && !_uncertain,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 4,
                          validator: (v) => _duplicates.isNotEmpty &&
                                  (v ?? '').trim().length < 10
                              ? context.mapText(
                                  'Explique a diferença com pelo menos 10 caracteres.',
                                  'Explain the difference in at least 10 characters.')
                              : null,
                          decoration: InputDecoration(
                              labelText: context.mapText(
                                  'Por que é um local distinto?',
                                  'Why is this a different place?'))),
                    ],
                    if (_error != null)
                      Semantics(liveRegion: true, child: Text(_error!)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(context.mapText(
                            _uncertain
                                ? 'Repetir mesma tentativa'
                                : 'Salvar local',
                            _uncertain ? 'Retry same request' : 'Save place'))),
                    if (_uncertain)
                      TextButton(
                          onPressed: _saving ? null : _newDraft,
                          child: Text(context.mapText('Iniciar outro rascunho',
                              'Start another draft'))),
                  ])))));
}
