import 'package:flutter/material.dart';

/// The usual navigation bar at default sizes; reflow and scroll for large text.
class ResponsiveNavigationBar extends StatelessWidget {
  const ResponsiveNavigationBar(
      {super.key,
      required this.destinations,
      required this.onSelected,
      this.selected = 0});
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;
  final int selected;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        if (MediaQuery.textScalerOf(context).scale(14) <= 18 &&
            bounds.maxWidth >= 320) {
          return NavigationBar(
              height: 80,
              selectedIndex: selected,
              destinations: destinations,
              onDestinationSelected: onSelected);
        }
        final width = bounds.maxWidth < 600
            ? bounds.maxWidth / 2
            : bounds.maxWidth / destinations.length;
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .30),
                child: SingleChildScrollView(
                  key: const ValueKey('map-navigation-scroll'),
                  child: Wrap(children: [
                    for (var i = 0; i < destinations.length; i++)
                      SizedBox(
                        width: width,
                        child: Semantics(
                            selected: selected == i,
                            child: TextButton(
                              onPressed: () => onSelected(i),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ExcludeSemantics(
                                        child: destinations[i].icon),
                                    Text(destinations[i].label,
                                        textAlign: TextAlign.center),
                                  ]),
                            )),
                      ),
                  ]),
                ),
              )),
        );
      });
}
