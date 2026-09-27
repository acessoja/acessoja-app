import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../l10n/strings.dart';
import '../services/app_http.dart';
import '../widgets/settings_page.dart';
import 'place_information_screen.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen(
      {super.key, required this.initialLocation, this.tileProvider});
  final LatLng initialLocation;
  final TileProvider? tileProvider;
  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _hours = TextEditingController();
  final _phone = TextEditingController();
  final _site = TextEditingController();
  final _photo = TextEditingController();
  final _entrance = TextEditingController();
  final Map<String, String> _resources = {};
  String _category = 'outro';
  LatLng? _point;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _hours,
      _phone,
      _site,
      _photo,
      _entrance
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPoint() async {
    final point = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
            builder: (_) => PlacePointScreen(
                initialLocation: _point ?? widget.initialLocation,
                tileProvider: widget.tileProvider)));
    if (mounted && point != null) setState(() => _point = point);
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_point == null) {
      setState(() => _error = context.l10n.locationRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final t = context.l10n;
    try {
      final existing =
          await AppHttp.get(Uri.parse('${Config.baseUrl}/api/locais/'));
      if (existing.statusCode != 200) {
        throw StateError('duplicate_check_failed');
      }
      final places = (jsonDecode(utf8.decode(existing.bodyBytes)) as List)
          .whereType<Map>()
          .where((place) {
        final name = (place['nome'] ?? '').toString().toLowerCase().trim();
        final proposed = _name.text.trim().toLowerCase();
        final lat = place['latitude'];
        final lon = place['longitude'];
        final near = lat is num &&
            lon is num &&
            const Distance()(LatLng(lat.toDouble(), lon.toDouble()), _point!) <
                80;
        return name.contains(proposed) || proposed.contains(name) || near;
      }).toList();
      if (!mounted) return;
      if (places.isNotEmpty) {
        final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  scrollable: true,
                  title: Text(t.possibleDuplicates),
                  content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.duplicateHelp),
                        for (final p in places.take(8))
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('${p['nome']}\n${p['endereco']}')),
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(t.checkExisting)),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t.differentPlace)),
                  ],
                ));
        if (proceed != true || !mounted) return;
      }
      final date = DateTime.now().toIso8601String().split('T').first;
      final payload = {
        'nome': _name.text.trim(),
        'endereco': _address.text.trim(),
        'latitude': _point!.latitude,
        'longitude': _point!.longitude,
        'imagem': _photo.text.trim(),
        'guia_visita': {
          'categoria': _category,
          'horarios': _hours.text.trim(),
          'telefone': _phone.text.trim(),
          'site': _site.text.trim(),
          'entrada': _entrance.text.trim(),
          'fonte': t.communitySource,
          'atualizado_em': date,
          'recursos': {
            for (final key in visitResourceLabels(context).keys)
              key: {
                'estado': _resources[key] ?? 'nao_informado',
                'fonte': t.communitySource,
                'atualizado_em': date,
              }
          },
        },
      };
      final response = await AppHttp.post(
          Uri.parse('${Config.baseUrl}/api/locais/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));
      if (response.statusCode != 201) throw StateError('create_failed');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = t.placeSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label,
          {bool required = false, int max = 255, bool url = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          enabled: !_saving,
          maxLength: max,
          minLines: 1,
          maxLines: url ? 1 : 3,
          keyboardType: url ? TextInputType.url : TextInputType.text,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (required && text.isEmpty) return context.l10n.fieldRequired;
            if (url && text.isNotEmpty) {
              final uri = Uri.tryParse(text);
              if (uri == null ||
                  !['https', 'http'].contains(uri.scheme) ||
                  uri.host.isEmpty) {
                return context.l10n.validWebLink;
              }
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: Text(t.addPlace)),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(t.addPlaceHelp),
                      const SizedBox(height: 20),
                      _field(_name, t.placeNameField, required: true),
                      _field(_address, t.placeAddressField, required: true),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: t.placeCategoryField),
                        items: {
                          'educacao': t.categoryEducation,
                          'alimentacao': t.categoryFood,
                          'saude': t.categoryHealth,
                          'comercio': t.categoryCommerce,
                          'servico': t.categoryService,
                          'lazer': t.categoryLeisure,
                          'outro': t.categoryOther,
                        }
                            .entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _category = value!),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed: _saving ? null : _pickPoint,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(t.pickLocation)),
                      if (_point != null)
                        Text(
                            '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}'),
                      const SizedBox(height: 24),
                      for (final resource
                          in visitResourceLabels(context).entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: DropdownButtonFormField<String>(
                            initialValue: 'nao_informado',
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText: resource.value,
                                border: const OutlineInputBorder()),
                            items: [
                              'nao_informado',
                              'disponivel',
                              'indisponivel',
                              'nao_se_aplica'
                            ]
                                .map((state) => DropdownMenuItem(
                                    value: state,
                                    child: Text(state == 'nao_informado'
                                        ? t.dontKnow
                                        : visitStatus(context, state))))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => _resources[resource.key] = value!,
                          ),
                        ),
                      _field(_entrance, t.optionalEntrance, max: 2000),
                      _field(_hours, t.optionalHours, max: 2000),
                      _field(_phone, t.optionalPhone, max: 40),
                      _field(_site, t.optionalSite, url: true, max: 200),
                      _field(_photo, t.optionalPhoto, url: true),
                      if (_error != null)
                        Semantics(
                            liveRegion: true,
                            child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)))),
                      FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _saving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator())
                                  : Text(t.publishPlace))),
                    ],
                  ))),
        ));
  }
}

class PlacePointScreen extends StatefulWidget {
  const PlacePointScreen(
      {super.key, required this.initialLocation, this.tileProvider});
  final LatLng initialLocation;
  final TileProvider? tileProvider;
  @override
  State<PlacePointScreen> createState() => _PlacePointScreenState();
}

class _PlacePointScreenState extends State<PlacePointScreen> {
  final _form = GlobalKey<FormState>();
  late final _lat =
      TextEditingController(text: widget.initialLocation.latitude.toString());
  late final _lon =
      TextEditingController(text: widget.initialLocation.longitude.toString());
  late LatLng _point = widget.initialLocation;
  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SettingsPage(title: t.pickLocation, children: [
      Text(t.pickLocationHelp),
      const SizedBox(height: 12),
      SizedBox(
          height: 280,
          child: FlutterMap(
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 16,
                onTap: (_, point) => setState(() {
                  _point = point;
                  _lat.text = '${point.latitude}';
                  _lon.text = '${point.longitude}';
                }),
              ),
              children: [
                TileLayer(
                    tileProvider: widget.tileProvider,
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.flutter_application_1'),
                MarkerLayer(markers: [
                  Marker(
                      point: _point,
                      child: const Icon(Icons.location_pin,
                          size: 40, color: Colors.red))
                ]),
              ])),
      const Text('© OpenStreetMap contributors'),
      const SizedBox(height: 16),
      Form(
          key: _form,
          child: Column(children: [
            for (final entry in [_lat, _lon].indexed)
              TextFormField(
                  controller: entry.$2,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                      labelText:
                          entry.$1 == 0 ? t.latitudeField : t.longitudeField),
                  validator: (value) {
                    final n =
                        double.tryParse((value ?? '').replaceAll(',', '.'));
                    final limit = entry.$1 == 0 ? 90 : 180;
                    return n == null || !n.isFinite || n.abs() > limit
                        ? t.invalidCoordinate
                        : null;
                  }),
          ])),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                  context,
                  LatLng(double.parse(_lat.text.replaceAll(',', '.')),
                      double.parse(_lon.text.replaceAll(',', '.'))));
            }
          },
          child: Text(t.confirmLocation)),
    ]);
  }
}
