import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps search resources alive through the bottom sheet's closing animation.
class MapSearchSheet extends StatefulWidget {
  final String initialText;
  final Widget Function(BuildContext, TextEditingController) builder;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<String>? onTextChanged;

  const MapSearchSheet({
    super.key,
    required this.initialText,
    required this.builder,
    this.onQueryChanged,
    this.onTextChanged,
  });

  @override
  State<MapSearchSheet> createState() => _MapSearchSheetState();
}

class _MapSearchSheetState extends State<MapSearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_scheduleSearch);
  }

  void _scheduleSearch() {
    widget.onTextChanged?.call(_controller.text);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) { widget.onQueryChanged?.call(_controller.text); setState(() {}); }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_scheduleSearch);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
