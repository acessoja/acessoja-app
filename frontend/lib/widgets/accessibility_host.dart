import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import '../app_preferences.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import 'accessibility_panel.dart';

/// Popup routes (dialogs, dropdowns and sheets) own interaction and semantics.
class AccessibilityRouteObserver extends NavigatorObserver {
  final blocked = ValueNotifier(false);
  final bottomClearance = ValueNotifier(0.0);
  final _clearances = <Route<dynamic>, double>{};
  final _routes = <Route<dynamic>>[];
  bool _scheduled = false;
  bool _disposed = false;
  void reportBottom(Route<dynamic> route, double? value) {
    if (_disposed || _clearances[route] == value) return;
    if (value == null) {
      _clearances.remove(route);
    } else {
      _clearances[route] = value;
    }
    _changed();
  }

  void dispose() {
    _disposed = true;
    blocked.dispose();
    bottomClearance.dispose();
  }

  void _changed() {
    if (_disposed || _scheduled) return;
    void publish() {
      if (_disposed) return;
      blocked.value = _routes.any((route) => route is PopupRoute);
      final pages = _routes.where((route) => route is! PopupRoute);
      bottomClearance.value = pages.isEmpty ? 0 : _clearances[pages.last] ?? 0;
      final overlayContext = navigator?.overlay?.context;
      if (overlayContext != null && overlayContext.mounted) {
        FocusScope.of(overlayContext).traversalEdgeBehavior =
            TraversalEdgeBehavior.parentScope;
      }
      for (final page in pages.whereType<PageRoute>()) {
        final context = page.subtreeContext;
        if (context != null && context.mounted) {
          FocusScope.of(context).traversalEdgeBehavior =
              TraversalEdgeBehavior.parentScope;
        }
      }
    }

    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle ||
        binding.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      publish();
    } else {
      _scheduled = true;
      binding.addPostFrameCallback((_) {
        _scheduled = false;
        publish();
      });
      binding.ensureVisualUpdate();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      route.completed.then((_) {
        _routes.remove(route);
        _changed();
      });
    } else {
      _routes.remove(route);
      _changed();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _routes.remove(oldRoute);
    if (newRoute != null) _routes.add(newRoute);
    _changed();
  }
}

class AccessibilityHost extends StatefulWidget {
  const AccessibilityHost(
      {super.key,
      required this.preferences,
      required this.observer,
      required this.navigatorKey,
      required this.child});
  final AppPreferences preferences;
  final AccessibilityRouteObserver observer;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<AccessibilityHost> createState() => _AccessibilityHostState();
}

class _AccessibilityHostState extends State<AccessibilityHost> {
  static const diameter = 56.0;
  final _focus = FocusNode(debugLabel: 'accessibility-button');
  Offset? _drag;
  bool _focused = false;
  late final _entry = OverlayEntry(builder: _buildLayer);
  @override
  void dispose() {
    _focus.dispose();
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value, Rect area) => Offset(
      value.dx.clamp(area.left, area.right).toDouble(),
      value.dy.clamp(area.top, area.bottom).toDouble());
  Future<void> _save(Offset visual, Rect base) async {
    final success =
        await widget.preferences.setAccessibilityButtonPosition(Offset(
      base.width <= 0 ? 0 : (visual.dx - base.left) / base.width,
      base.height <= 0 ? 0 : (visual.dy - base.top) / base.height,
    ));
    if (!success && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.readingSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    _entry.markNeedsBuild();
    return Overlay(initialEntries: [_entry]);
  }

  Widget _buildLayer(BuildContext context) => ValueListenableBuilder<double>(
      valueListenable: widget.observer.bottomClearance,
      builder: (context, clearance, _) =>
          LayoutBuilder(builder: (context, constraints) {
            final media = MediaQuery.of(context),
                colors = AppColors.of(context);
            final left = media.viewPadding.left + 12,
                top = media.viewPadding.top + 12;
            // Reserve the main bottom navigation and leave a gap above the keyboard.
            final base = Rect.fromLTRB(
                left,
                top,
                math.max(
                    left,
                    constraints.maxWidth -
                        media.viewPadding.right -
                        12 -
                        diameter),
                math.max(
                    top,
                    constraints.maxHeight -
                        media.viewPadding.bottom -
                        math.max(92, clearance + 12) -
                        diameter));
            final useful = Rect.fromLTRB(
                base.left,
                base.top,
                base.right,
                math.max(
                    top,
                    math.min(
                        base.bottom,
                        constraints.maxHeight -
                            media.viewInsets.bottom -
                            12 -
                            diameter)));
            final saved = widget.preferences.buttonPosition;
            final visual = _clamp(
                _drag ??
                    Offset(base.left + saved.dx * base.width,
                        base.top + saved.dy * base.height),
                useful);
            void nudge(Offset delta) {
              _save(_clamp(visual + delta, useful), base);
            }

            return _HostScope(
                observer: widget.observer,
                child: FocusTraversalGroup(
                    child: Stack(fit: StackFit.expand, children: [
                  widget.child,
                  Positioned(
                    left: visual.dx,
                    top: visual.dy,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: widget.observer.blocked,
                      builder: (context, blocked, _) => Visibility(
                        visible: widget.preferences.showAccessibilityButton &&
                            !blocked,
                        maintainState: true,
                        child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowLeft):
                                  () => nudge(const Offset(-24, 0)),
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowRight):
                                  () => nudge(const Offset(24, 0)),
                              const SingleActivator(LogicalKeyboardKey.arrowUp):
                                  () => nudge(const Offset(0, -24)),
                              const SingleActivator(
                                      LogicalKeyboardKey.arrowDown):
                                  () => nudge(const Offset(0, 24)),
                            },
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              onPanStart: (_) => setState(() => _drag = visual),
                              onPanUpdate: (event) => setState(() => _drag =
                                  _clamp(
                                      (_drag ?? visual) + event.delta, useful)),
                              onPanEnd: (_) {
                                final position = _drag ?? visual;
                                setState(() => _drag = null);
                                _save(position, base);
                              },
                              onPanCancel: () => setState(() => _drag = null),
                              child: Focus(
                                skipTraversal: true,
                                canRequestFocus: false,
                                onFocusChange: (value) =>
                                    setState(() => _focused = value),
                                child: SizedBox.square(
                                    dimension: diameter,
                                    child: Material(
                                      color: colors.primary,
                                      elevation: 4,
                                      shape: CircleBorder(
                                          side: BorderSide(
                                              width: _focused ? 3 : 1,
                                              color: _focused
                                                  ? colors.onPrimary
                                                  : colors.primary)),
                                      child: Semantics(
                                          label: context.l10n.readingOpen,
                                          button: true,
                                          child: Tooltip(
                                              message: context.l10n.readingOpen,
                                              excludeFromSemantics: true,
                                              child: IconButton(
                                                key: const ValueKey(
                                                    'accessibility-floating-button'),
                                                focusNode: _focus,
                                                onPressed: () {
                                                  final target = widget
                                                      .navigatorKey
                                                      .currentState
                                                      ?.overlay
                                                      ?.context;
                                                  if (target != null) {
                                                    showAccessibilityPanel(
                                                        target,
                                                        returnFocus: _focus);
                                                  }
                                                },
                                                color: colors.onPrimary,
                                                icon: const Icon(
                                                    Icons.accessibility_new),
                                              ))),
                                    )),
                              ),
                            )),
                      ),
                    ),
                  ),
                ])));
          }));
}

class _HostScope extends InheritedWidget {
  const _HostScope({required this.observer, required super.child});
  final AccessibilityRouteObserver observer;
  @override
  bool updateShouldNotify(_HostScope oldWidget) =>
      observer != oldWidget.observer;
}

/// Reports the real height of map navigation/footer panels, including text reflow.
class AccessibilityBottomBoundary extends StatefulWidget {
  const AccessibilityBottomBoundary({super.key, required this.child});
  final Widget child;
  @override
  State<AccessibilityBottomBoundary> createState() =>
      _AccessibilityBottomBoundaryState();
}

class _AccessibilityBottomBoundaryState
    extends State<AccessibilityBottomBoundary> {
  final _box = GlobalKey();
  AccessibilityRouteObserver? _observer;
  Route<dynamic>? _route;
  void _measure() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _observer == null || _route == null) return;
        final box = _box.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          _observer!.reportBottom(
              _route!,
              (MediaQuery.sizeOf(context).height -
                      box.localToGlobal(Offset.zero).dy)
                  .clamp(0, double.infinity)
                  .toDouble());
        }
      });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer =
        context.dependOnInheritedWidgetOfExactType<_HostScope>()?.observer;
    _route = ModalRoute.of(context);
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: SizeChangedLayoutNotifier(
          child: SizedBox(key: _box, child: widget.child)),
    );
  }

  @override
  void dispose() {
    if (_route != null) _observer?.reportBottom(_route!, null);
    super.dispose();
  }
}
