import 'package:flutter/material.dart';
import '../services/favorites_controller.dart';

class FavoritesScope extends InheritedNotifier<FavoritesController> {
  const FavoritesScope(
      {super.key,
      required FavoritesController controller,
      required super.child})
      : super(notifier: controller);
  static FavoritesController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FavoritesScope>()?.notifier;
}
