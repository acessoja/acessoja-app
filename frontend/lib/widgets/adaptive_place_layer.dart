import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../models/map_place.dart';
import '../models/map_marker_layout.dart';
import '../models/place_category.dart';
import '../models/personal_list.dart';
import '../services/app_http.dart';
import '../services/personal_lists_service.dart';

class AdaptivePlaceLayer extends StatefulWidget {
  final List<MapPlace> places;
  final String? selectedId;
  final ValueChanged<MapPlace> onSelect;
  final void Function(LatLng center, List<MapPlace> members) onCluster;
  final EdgeInsets reservedInsets;
  final List<Rect> reservedRects;
  final ValueChanged<FocusNode>? onReturnFocusTarget;
  const AdaptivePlaceLayer({
    super.key,
    required this.places,
    this.selectedId,
    required this.onSelect,
    required this.onCluster,
    this.reservedInsets = EdgeInsets.zero,
    this.reservedRects = const [],
    this.onReturnFocusTarget,
  });
  @override
  State<AdaptivePlaceLayer> createState() => _AdaptivePlaceLayerState();
}

class _AdaptivePlaceLayerState extends State<AdaptivePlaceLayer> {
  final _focusNodes = <String, FocusNode>{};
  int _listLoadGeneration = 0;
  int _layerLoadGeneration = 0;
  @override
  void initState() {
    super.initState();
    personalListsRevision.addListener(_personalChanged);
    _loadPersonalLists();
  }

  void _personalChanged() {
    if (mounted) {
      _listLoadGeneration++;
      _layerLoadGeneration++;
      _personal = {};
      _personalKey = '';
      if (!AppHttp.authenticated) {
        _lists = const [];
        _personalListId = null;
      }
      setState(() {});
      _loadPersonalLists();
    }
  }

  Future<void> _loadPersonalLists() async {
    final session = AppHttp.sessionRevision.value;
    final generation = ++_listLoadGeneration;
    if (!AppHttp.authenticated) {
      if (mounted) setState(() => _lists = const []);
      return;
    }
    try {
      final lists = await _personalService.lists(session: session);
      if (mounted &&
          generation == _listLoadGeneration &&
          session == AppHttp.sessionRevision.value) {
        setState(() => _lists = lists);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    personalListsRevision.removeListener(_personalChanged);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(PlaceMarkerLayout item) {
    final focus = _focusNodes[item.stableKey];
    if (focus != null) {
      widget.onReturnFocusTarget?.call(focus);
    }
    if (item.isCluster) {
      widget.onCluster(item.point, item.members);
    } else {
      widget.onSelect(item.place);
    }
  }

  final _measurements =
      <(String, TextStyle, TextScaler, TextDirection), Size>{};
  final _personalService = const PersonalListsService();
  Map<int, PersonalMarker> _personal = {};
  List<PersonalList> _lists = const [];
  int? _personalListId;
  bool _personalVisible = true, _onlyPersonal = false;
  String _personalKey = '';

  Future<void> _loadPersonalLayer(List<MapPlace> places) async {
    if (!_personalVisible) {
      if (_personal.isNotEmpty) {
        _layerLoadGeneration++;
        setState(() => _personal = {});
      }
      return;
    }
    if (!AppHttp.authenticated) {
      if (_personal.isNotEmpty || _personalKey.isNotEmpty) {
        _personal = {};
        _personalKey = '';
        if (mounted) setState(() {});
      }
      return;
    }
    final ids = places
        .where((place) => !place.isExternal && place.internalId != null)
        .map((place) => place.internalId!)
        .toSet()
        .toList();
    final session = AppHttp.sessionRevision.value;
    final key =
        '$session:${personalListsRevision.value}:$_personalListId:${ids.join(',')}';
    if (key == _personalKey) return;
    _personalKey = key;
    final generation = ++_layerLoadGeneration;
    try {
      final value = <int, PersonalMarker>{};
      for (var offset = 0; offset < ids.length; offset += 100) {
        final batch = ids.skip(offset).take(100);
        value.addAll(
          await _personalService.markerLayer(
            batch,
            session: session,
            listId: _personalListId,
          ),
        );
      }
      if (mounted &&
          generation == _layerLoadGeneration &&
          key == _personalKey &&
          session == AppHttp.sessionRevision.value) {
        setState(() => _personal = value);
      }
    } catch (_) {
      if (mounted &&
          generation == _layerLoadGeneration &&
          key == _personalKey) {
        setState(() => _personal = {});
      }
    }
  }

  Size _measure(String text, TextStyle style, BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final key = (text, effective, scaler, direction);
    if (_measurements.length > 1024) {
      _measurements.clear();
    }
    return _measurements.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: text, style: effective),
        textDirection: direction,
        maxLines: 1,
        textScaler: scaler,
      );
      painter.layout(maxWidth: 200);
      final result = painter.size;
      painter.dispose();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The inherited camera updates this layer immediately during map gestures.
    final camera = MapCamera.of(context);
    final colors = AppColors.of(context);
    _loadPersonalLayer(widget.places);
    final places = _onlyPersonal
        ? widget.places
              .where((place) => _personal.containsKey(place.internalId))
              .toList()
        : widget.places;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: colors.text,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final insets = widget.reservedInsets;
        final controlOffset = _personalControlOffset(size, insets);
        final layouts = layoutPlaceMarkers(
          places: places,
          center: camera.center,
          zoom: camera.zoom,
          size: size,
          selectedId: widget.selectedId,
          projectScreen: (point) {
            final screen = camera.latLngToScreenPoint(point);
            return Offset(screen.x, screen.y);
          },
          reserved: [
            ...widget.reservedRects,
            Rect.fromLTWH(controlOffset.dx, controlOffset.dy, 56, 56),
            if (insets.left > 0) Rect.fromLTWH(0, 0, insets.left, size.height),
            if (insets.top > 0) Rect.fromLTWH(0, 0, size.width, insets.top),
            if (insets.bottom > 0)
              Rect.fromLTWH(
                0,
                size.height - insets.bottom,
                size.width,
                insets.bottom,
              ),
            if (insets.right > 0)
              Rect.fromLTWH(
                size.width - insets.right,
                0,
                insets.right,
                size.height,
              ),
          ],
          measure: (name) => _measure(
            name.isEmpty ? context.mapText('Sem nome', 'Unnamed') : name,
            style,
            context,
          ),
        );
        return Stack(
          children: [
            Positioned(
              top: controlOffset.dy,
              left: controlOffset.dx,
              child: _personalControls(context),
            ),
            for (final item in layouts.where((item) => !item.occluded))
              Positioned(
                key: ValueKey('symbol-${item.stableKey}'),
                left: item.hitBounds.left,
                top: item.hitBounds.top,
                width: item.markerSize.width,
                height: item.markerSize.height,
                child: _button(context, item),
              ),
            for (final item in layouts)
              if (item.label != null)
                Positioned.fromRect(
                  key: ValueKey('label-${item.stableKey}'),
                  rect: item.label!,
                  child: ExcludeSemantics(
                    child: ExcludeFocus(
                      child: Tooltip(
                        message: context.placeName(item.place),
                        excludeFromSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(item),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border.all(color: colors.primaryDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                context.placeName(item.place),
                                style: style,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Offset _personalControlOffset(Size size, EdgeInsets insets) {
    const extent = 56.0, step = 64.0, edge = 12.0;
    final top =
        math.max(MediaQuery.paddingOf(context).top, insets.top).toDouble() +
        edge;
    for (
      var y = top;
      y + extent <= size.height - insets.bottom - edge;
      y += step
    ) {
      for (
        var x = math.max(edge, insets.left + edge).toDouble();
        x + extent <= size.width - insets.right - edge;
        x += step
      ) {
        final bounds = Rect.fromLTWH(x, y, extent, extent);
        if (!widget.reservedRects.any(
          (reserved) => reserved.overlaps(bounds),
        )) {
          return Offset(x, y);
        }
      }
    }
    return Offset(edge, top);
  }

  Widget _personalControls(BuildContext context) => Card(
    key: const ValueKey('map-personal-layers'),
    margin: EdgeInsets.zero,
    child: PopupMenuButton<String>(
      tooltip: 'Camada Meus lugares',
      icon: Icon(_personalVisible ? Icons.layers : Icons.layers_clear),
      onSelected: (value) {
        if (value == 'visibility') {
          setState(() {
            _personalVisible = !_personalVisible;
            _personalKey = '';
            if (!_personalVisible) {
              _layerLoadGeneration++;
              _personal = {};
            }
          });
        }
        if (value == 'only') setState(() => _onlyPersonal = !_onlyPersonal);
        if (value.startsWith('list:')) {
          setState(() {
            _personalListId = int.tryParse(value.substring(5));
            _personalKey = '';
          });
        }
        if (value == 'all') {
          setState(() {
            _personalListId = null;
            _personalKey = '';
          });
        }
        if (value == 'legend') _showLegend(context);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'visibility',
          checked: _personalVisible,
          child: const Text('Mostrar meus lugares'),
        ),
        CheckedPopupMenuItem(
          value: 'only',
          checked: _onlyPersonal,
          child: const Text('Somente meus lugares'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'all', child: Text('Todas as listas')),
        ..._lists.map(
          (list) =>
              PopupMenuItem(value: 'list:${list.id}', child: Text(list.name)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'legend', child: Text('Legenda da camada')),
      ],
    ),
  );

  void _showLegend(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Legenda — Meus lugares'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.flag),
            title: Text('Quero visitar'),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: Icon(Icons.check_circle),
            title: Text('Já visitei'),
            contentPadding: EdgeInsets.zero,
          ),
          Text('A presença no mapa é pessoal e não comprova acessibilidade.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  Widget _button(BuildContext context, PlaceMarkerLayout item) {
    final colors = AppColors.of(context);
    final selected = item.containsSelection(widget.selectedId);
    final personal = item.isCluster ? null : _personal[item.place.internalId];
    final recognized = !item.isCluster && item.place.hasCommunityRecognition;
    final highlight = !item.isCluster && item.place.hasCommunityHighlight;
    final visual = categoryVisual(item.place.category);
    final visitLabel = personal?.status == PersonalVisitStatus.want
        ? 'Quero visitar'
        : personal?.status == PersonalVisitStatus.visited
        ? 'Já visitei'
        : null;
    final label = item.isCluster
        ? context.mapText(
                '${item.members.length} locais na mesma coordenada. Abrir lista.',
                '${item.members.length} places at the same coordinate. Open list.',
              ) +
              (selected
                  ? ' ${context.mapText('Inclui o local selecionado', 'Includes selected place')}: ${context.placeName(item.place)}.'
                  : '')
        : '${context.placeName(item.place)}. ${context.placeCategory(item.place)}. ${item.place.sourceLabel}. '
              '${recognized ? context.mapText('Reconhecimento comunitário de acessibilidade. ', 'Community accessibility recognition. ') : ''}'
              '${highlight ? context.mapText('Destaque superior da comunidade. ', 'Community highlight. ') : ''}'
              '${personal?.lists.isNotEmpty == true ? 'Listas: ${personal!.lists.join(', ')}. ' : ''}'
              '${visitLabel == null ? '' : '$visitLabel. '}'
              '${selected ? context.mapText('Selecionado. O realce azul não altera a classificação de acessibilidade. ', 'Selected. The blue highlight does not change the accessibility classification. ') : ''}'
              '${context.mapText('Abrir local', 'Open place')}';
    return MergeSemantics(
      child: Semantics(
        label: label,
        selected: selected,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: TextButton(
            key: ValueKey(item.stableKey),
            focusNode: _focusNodes.putIfAbsent(
              item.stableKey,
              () => FocusNode(),
            ),
            onPressed: () => _select(item),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              foregroundColor: WidgetStatePropertyAll(colors.primaryDark),
              shape: const WidgetStatePropertyAll(CircleBorder()),
              side: const WidgetStatePropertyAll(BorderSide.none),
            ),
            child: ExcludeSemantics(
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (highlight)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4A017),
                            width: 2,
                          ),
                        ),
                      ),
                    if (selected)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primarySoft.withValues(alpha: .45),
                          border: Border.all(color: colors.primary, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .22),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    if (!selected && !highlight)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface,
                          border: Border.all(color: visual.color, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: .35),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: selected ? 32 : 28,
                      height: selected ? 32 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? colors.primary : colors.surface,
                        border: highlight
                            ? Border.all(
                                color: const Color(0xFFD4A017),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Icon(
                        item.isCluster ? Icons.layers_outlined : visual.icon,
                        color: selected ? colors.onPrimary : visual.color,
                        size: selected ? 21 : 20,
                      ),
                    ),
                    if (recognized)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.accessible_forward,
                            size: 14,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    if (visitLabel != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(
                          personal!.status == PersonalVisitStatus.visited
                              ? Icons.check_circle
                              : Icons.flag,
                          size: 13,
                          color: colors.text,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
