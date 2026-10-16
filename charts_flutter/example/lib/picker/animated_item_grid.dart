import 'dart:async';

import 'package:example/picker/tag_item_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AnimatedItemGrid<T> extends StatefulWidget {
  AnimatedItemGrid({
    required this.items,
    required this.selectedTags,
    required Widget Function(BuildContext context, T item) builder,
    super.key,
  }) : _builder = ((context, item) => builder(context, item as T));

  final List<T> items;
  final ValueNotifier<List<TagDefinition>> selectedTags;
  final Widget Function(BuildContext context, Object? item) _builder;

  Widget buildItem(BuildContext context, T item) => _builder(context, item);

  @override
  State<AnimatedItemGrid<T>> createState() => _AnimatedItemGridState();
}

class _AnimatedItemGridState<T> extends State<AnimatedItemGrid<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    unawaited(_controller.forward());
  }

  @override
  void didUpdateWidget(AnimatedItemGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areItemListsEqual(widget.items, oldWidget.items)) {
      _controller.reset();
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _areItemListsEqual(List<T> list1, List<T> list2) =>
      list1.length == list2.length &&
      list1.every(
        (item) => list2.any(
          (otherItem) => item == otherItem,
        ),
      );

  @override
  Widget build(BuildContext context) => AnimationLimiter(
        key: ValueKey(widget.items.length),
        child: Wrap(
          runAlignment: WrapAlignment.center,
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 200),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: ScaleAnimation(
                  scale: 0.5,
                  child: widget,
                ),
              ),
            ),
            children: widget.items
                .map(
                  (item) => widget.buildItem(context, item),
                )
                .toList(),
          ),
        ),
      );
}
