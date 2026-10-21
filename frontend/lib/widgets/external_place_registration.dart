import '../screens/login_screen.dart';
import '../l10n/contribution_strings.dart';
import '../l10n/strings.dart';
import '../services/app_http.dart';

import 'package:flutter/material.dart';

import '../services/places_service.dart';
import '../services/favorites_controller.dart';
import '../services/review_changes.dart';
import 'favorites_scope.dart';

/// Confirma nome/endereço e autentica somente esta escrita. A senha não é
/// persistida nem enviada para OSM; coordenadas vêm do token assinado da API.
class ExternalPlaceRegistration extends StatefulWidget {
  final Map<String, dynamic> place;
  final String userName;
  final bool forFavorite;
  const ExternalPlaceRegistration({
    super.key,
    required this.place,
    required this.userName,
    this.forFavorite = false,
  });

  @override
  State<ExternalPlaceRegistration> createState() => _RegistrationState();
}

class _RegistrationState extends State<ExternalPlaceRegistration> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.place['name_is_fallback'] == true
        ? ''
        : widget.place['nome']?.toString(),
  );
  late final _address = TextEditingController(
    text: widget.place['endereco']?.toString(),
  );
  final _password = TextEditingController();
  int _session = AppHttp.sessionRevision.value;
  bool _saving = false;
  String? _error;
  bool get _catalog => widget.place['catalog_id'] is int;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: (context, user) => Navigator.pop(context, true),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _session = AppHttp.sessionRevision.value;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_catalog && !AppHttp.authenticated && !_saving) {
      await _login();
      return;
    }
    if (_session != AppHttp.sessionRevision.value ||
        _saving ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final favorites = widget.forFavorite && _catalog
          ? FavoritesScope.maybeOf(context)
          : null;
      final local = await const PlacesService().importExternalPlace(
        place: widget.place,
        name: _name.text,
        address: _address.text,
        userName: AppHttp.userName ?? widget.userName,
        password: _password.text,
      );
      _password.clear();
      if (mounted &&
          _session == AppHttp.sessionRevision.value &&
          widget.forFavorite &&
          _catalog) {
        if (favorites == null) {
          throw const PlacesException(
            'Favoritos indisponíveis. Tente novamente.',
            503,
          );
        }
        final id = local['id_local'] as int;
        favorites.rememberExternal(
          widget.place['external_id'].toString(),
          id,
          _session,
        );
        final outcome = await favorites.setSaved(id, true);
        if (outcome != FavoriteOutcome.confirmed) {
          throw const PlacesException(
            'Cadastro confirmado. Não foi possível confirmar o favorito; tente novamente.',
            503,
          );
        }
        local['_catalog_favorite_completed'] = true;
      }
      if (mounted && _session == AppHttp.sessionRevision.value) {
        if (_catalog) {
          reviewChanges.value++;
        }
        Navigator.pop(context, local);
      }
    } catch (error) {
      if (widget.forFavorite &&
          error is PlacesException &&
          error.status == 401 &&
          _session == AppHttp.sessionRevision.value) {
        AppHttp.clearSession();
      }
      if (mounted) {
        setState(
          () => _error = error is PlacesException
              ? error.message
              : 'Cadastro indisponível. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo.' : null;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(
            widget.forFavorite
                ? context.l10n.favoriteRegisterTitle
                : context.contributionText(
                    'Contribuir com o AcessoJá',
                    'Contribute to AcessoJá',
                  ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.forFavorite
                        ? context.l10n.favoriteRegisterHelp
                        : context.contributionText(
                            'Confira o nome e, se houver, o endereço do OpenStreetMap. Se o endereço não estiver disponível, deixe-o em branco; a posição do local já está associada ao catálogo. Depois você poderá avaliar a acessibilidade.',
                            'Check the name and any available OpenStreetMap address. If no address is known, leave it blank; the catalog already has the place location. You can review accessibility afterwards.',
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    maxLength: 255,
                    enabled: !_saving,
                    validator: _required,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.contributionText(
                        'Nome do local',
                        'Place name',
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _address,
                    maxLength: 255,
                    enabled: !_saving,
                    validator: _catalog ? null : _required,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _catalog
                          ? context.contributionText('Endereço (se conhecido)', 'Address (if known)')
                          : context.contributionText('Endereço', 'Address'),
                    ),
                  ),
                  if (AppHttp.token == null && !_catalog)
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      enabled: !_saving,
                      validator: _required,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: context.contributionText(
                          'Confirme sua senha',
                          'Confirm your password',
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  if (_error != null)
                    Semantics(liveRegion: true, child: Text(_error!)),
                ],
              ),
            ),
          ),
          actions: [
            if (!AppHttp.authenticated ||
                _session != AppHttp.sessionRevision.value)
              TextButton(
                onPressed: _saving ? null : _login,
                child: Text(
                  context.contributionText(
                    'Entrar e continuar',
                    'Sign in and continue',
                  ),
                ),
              ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(context.contributionText('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving
                    ? context.contributionText(
                        'Confirmando cadastro…',
                        'Registering…',
                      )
                    : context.contributionText(
                        'Confirmar cadastro',
                        'Confirm registration',
                      ),
              ),
            ),
          ],
        ),
      );
}
