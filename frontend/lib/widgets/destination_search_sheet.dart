import 'package:flutter/material.dart';

/// Keeps the text controller alive until the closing animation has unmounted
/// the sheet, rather than disposing it when Navigator.pop completes.
class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet(
      {super.key, required this.initialDestination, required this.builder});

  final String initialDestination;
  final Widget Function(BuildContext, StateSetter, TextEditingController)
      builder;

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  late final _controller =
      TextEditingController(text: widget.initialDestination);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, setState, _controller);
}
