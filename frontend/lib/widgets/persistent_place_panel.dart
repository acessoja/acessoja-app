import 'package:flutter/material.dart';

import '../services/place_preview_controller.dart';
import 'map_place_preview.dart';
import 'accessibility_host.dart';
import '../services/route_service.dart';

/// No route/barrier: hit testing belongs only to the visible sheet/siderail.
class PersistentPlacePanel extends StatefulWidget {
  const PersistentPlacePanel({
    super.key,
    required this.controller,
    required this.distanceLabel,
    required this.onAction,
    required this.onGeometry,
    required this.onClose,
    this.preferredResources = const {},
    this.outsideResults = false,
    this.onSearch,
    this.externalNavigation = const ExternalNavigation(),
  });
  final PlacePreviewController controller;
  final ExternalNavigation externalNavigation;
  final String Function(Map<String, dynamic>) distanceLabel;
  final ValueChanged<String> onAction;
  final ValueChanged<Rect> onGeometry;
  final VoidCallback onClose;
  final Set<String> preferredResources;
  final bool outsideResults;
  final VoidCallback? onSearch;
  @override
  State<PersistentPlacePanel> createState() => _PersistentPlacePanelState();
}

class _PersistentPlacePanelState extends State<PersistentPlacePanel> {
  final _sheet = DraggableScrollableController();
  final _sideScroll = ScrollController();
  Rect? _reported;
  GlobalKey _contentKey = GlobalKey();
  String? _contentIdentity;
  bool? _wide;
  String? _identity;
  PlacePanelLevel? _level;
  PlacePanelSection? _section;
  bool _sizing = false, _geometryQueued = false;
  @override
  void initState() {
    super.initState();
    _sheet.addListener(_sheetChanged);
  }

  void _sheetChanged() {
    if (_geometryQueued) return;
    _geometryQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryQueued = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sheet.removeListener(_sheetChanged);
    _sheet.dispose();
    _sideScroll.dispose();
    super.dispose();
  }

  void _report(Rect rect) {
    if (rect == _reported) {
      return;
    }
    _reported = rect;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reported == rect) {
        widget.onGeometry(rect);
      }
    });
  }

  Widget _content(ScrollController scroll) {
    final c = widget.controller, p = c.place!;
    if (_contentIdentity != p.id) {
      _contentIdentity = p.id;
      _contentKey = GlobalKey();
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0) {
          c.rememberOffset(n.metrics.pixels);
        }
        return false;
      },
      child: MapPlacePreview(
        externalNavigation: widget.externalNavigation,
        key: _contentKey,
        place: p.toMap(),
        coordinator: c,
        scrollController: scroll,
        preferredResources: widget.preferredResources,
        outsideResults: widget.outsideResults,
        distanceLabel: widget.distanceLabel(p.toMap()),
        loadingDetails: c.loading,
        detailsFailed: c.failed,
        onRetryDetails: c.retry,
        onClosePressed: widget.onClose,
        onDetailsPressed: c.expand,
        onSearchPressed: widget.onSearch,
        onRoutePressed: p.hasCoordinates && !c.unavailable
            ? () => widget.onAction('route')
            : null,
        onPickPointPressed: !p.hasCoordinates
            ? () => widget.onAction('recover')
            : null,
        onEvaluatePressed:
            !c.unavailable && (p.internalId != null || p.isExternal)
            ? () => widget.onAction('evaluate')
            : null,
        onReviewsPressed: c.reviewTarget == null
            ? null
            : () => widget.onAction('reviews'),
        onContributePressed:
            p.isExternal && p.internalId == null && !c.unavailable
            ? () => widget.onAction('contribute')
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.visible) {
        _reported = null;
        return const SizedBox.shrink();
      }
      return LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 1000;
          final compact = c.level == PlacePanelLevel.compact;
          // Keep the map's 48/52 px header controls reachable on short screens.
          final maximum = bounds.maxHeight <= 0
              ? .90
              : (1 - 80 / bounds.maxHeight).clamp(.45, .90).toDouble();
          final desired = compact ? .38 : maximum;
          final changed =
              _wide != wide ||
              _identity != c.place!.id ||
              _level != c.level ||
              _section != c.section;
          _wide = wide;
          _identity = c.place!.id;
          _level = c.level;
          _section = c.section;
          if (changed && !_sizing) {
            _sizing = true;
            final offset = c.scrollOffset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sizing = false;
              if (!mounted || !c.visible) {
                return;
              }
              if (!wide && _sheet.isAttached) {
                _sheet.jumpTo(desired);
              }
              final scroll = wide
                  ? _sideScroll
                  : (_sheet.isAttached ? _sheetController : null);
              if (scroll != null && scroll.hasClients) {
                scroll.jumpTo(offset.clamp(0, scroll.position.maxScrollExtent));
              }
            });
          }
          if (wide) {
            final width = (bounds.maxWidth * .38).clamp(360.0, 460.0);
            final height = compact
                ? (bounds.maxHeight * .72).clamp(0.0, bounds.maxHeight)
                : bounds.maxHeight;
            _report(
              Rect.fromLTWH(
                bounds.maxWidth - width,
                bounds.maxHeight - height,
                width,
                height,
              ),
            );
            return Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: width,
                height: height,
                child: _surface(_content(_sideScroll), side: true),
              ),
            );
          }
          final fraction = _sheet.isAttached ? _sheet.size : desired;
          _report(
            Rect.fromLTWH(
              0,
              bounds.maxHeight * (1 - fraction),
              bounds.maxWidth,
              bounds.maxHeight * fraction,
            ),
          );
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              if (!mounted || _sizing) {
                return false;
              }
              final expand = n.extent >= (maximum * .85).clamp(.45, .7);
              final collapse = n.extent <= .42;
              if ((expand && c.level != PlacePanelLevel.expanded) ||
                  (collapse && c.level != PlacePanelLevel.compact)) {
                final ticket = c.capture();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && c.visible && c.owns(ticket)) {
                    if (expand) {
                      c.expand();
                    } else {
                      c.collapse();
                    }
                  }
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: desired,
              minChildSize: .28,
              maxChildSize: maximum,
              snap: true,
              snapSizes: [.38, if (maximum > .6) .6],
              shouldCloseOnMinExtent: false,
              builder: (context, scroll) {
                _sheetController = scroll;
                return _surface(_content(scroll));
              },
            ),
          );
        },
      );
    },
  );
  ScrollController? _sheetController;
  Widget _surface(Widget child, {bool side = false}) {
    final surface = Material(
      elevation: 10,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    );
    return side
        ? AccessibilitySideBoundary(child: surface)
        : AccessibilityBottomBoundary(child: surface);
  }
}
