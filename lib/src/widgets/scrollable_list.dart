// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'framework.dart';
import 'scroll_behavior.dart';
import 'scrollable.dart';
import 'virtual_viewport.dart';

import 'package:flutter/rendering.dart';

class ScrollableList extends Scrollable {
  ScrollableList({
    Key key,
    double initialScrollOffset,
    Axis scrollDirection: Axis.vertical,
    ViewportAnchor scrollAnchor: ViewportAnchor.start,
    ScrollListener onScroll,
    SnapOffsetCallback snapOffsetCallback,
    this.itemExtent,
    this.itemsWrap: false,
    this.padding,
    this.scrollableListPainter,
    this.children
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    scrollDirection: scrollDirection,
    scrollAnchor: scrollAnchor,
    onScroll: onScroll,
    snapOffsetCallback: snapOffsetCallback
  ) {
    assert(itemExtent != null);
  }

  final double itemExtent;
  final bool itemsWrap;
  final EdgeDims padding;
  final ScrollableListPainter scrollableListPainter;
  final Iterable<Widget> children;

  ScrollableState createState() => new _ScrollableListState();
}

class _ScrollableListState extends ScrollableState<ScrollableList> {
  ScrollBehavior<double, double> createScrollBehavior() => new OverscrollBehavior();
  ExtentScrollBehavior get scrollBehavior => super.scrollBehavior;

  void _handleExtentsChanged(double contentExtent, double containerExtent) {
    config.scrollableListPainter?.contentExtent = contentExtent;
    setState(() {
      scrollTo(scrollBehavior.updateExtents(
        contentExtent: config.itemsWrap ? double.INFINITY : contentExtent,
        containerExtent: containerExtent,
        scrollOffset: scrollOffset
      ));
    });
  }

  void dispatchOnScrollStart() {
    super.dispatchOnScrollStart();
    config.scrollableListPainter?.scrollStarted();
  }

  void dispatchOnScroll() {
    super.dispatchOnScroll();
    config.scrollableListPainter?.scrollOffset = scrollOffset;
  }

  void dispatchOnScrollEnd() {
    super.dispatchOnScrollEnd();
    config.scrollableListPainter?.scrollEnded();
  }

  Widget buildContent(BuildContext context) {
    return new ListViewport(
      onExtentsChanged: _handleExtentsChanged,
      scrollOffset: scrollOffset,
      scrollDirection: config.scrollDirection,
      scrollAnchor: config.scrollAnchor,
      itemExtent: config.itemExtent,
      itemsWrap: config.itemsWrap,
      padding: config.padding,
      overlayPainter: config.scrollableListPainter,
      children: config.children
    );
  }
}

class _VirtualListViewport extends VirtualViewport {
  _VirtualListViewport(
    this.onExtentsChanged,
    this.scrollOffset,
    this.scrollDirection,
    this.scrollAnchor,
    this.itemExtent,
    this.itemsWrap,
    this.padding,
    this.overlayPainter
  ) {
    assert(scrollDirection != null);
    assert(itemExtent != null);
  }

  final ExtentsChangedCallback onExtentsChanged;
  final double scrollOffset;
  final Axis scrollDirection;
  final ViewportAnchor scrollAnchor;
  final double itemExtent;
  final bool itemsWrap;
  final EdgeDims padding;
  final Painter overlayPainter;

  double get _leadingPadding {
    switch (scrollDirection) {
      case Axis.vertical:
        switch (scrollAnchor) {
          case ViewportAnchor.start:
            return padding.top;
          case ViewportAnchor.end:
            return padding.bottom;
        }
        break;
      case Axis.horizontal:
        switch (scrollAnchor) {
          case ViewportAnchor.start:
            return padding.left;
          case ViewportAnchor.end:
            return padding.right;
        }
        break;
    }
  }

  double get startOffset {
    if (padding == null)
      return scrollOffset;
    return scrollOffset - _leadingPadding;
  }

  RenderList createRenderObject(BuildContext context) => new RenderList(itemExtent: itemExtent);

  _VirtualListViewportElement createElement() => new _VirtualListViewportElement(this);
}

class _VirtualListViewportElement extends VirtualViewportElement {
  _VirtualListViewportElement(VirtualViewport widget) : super(widget);

  _VirtualListViewport get widget => super.widget;

  RenderList get renderObject => super.renderObject;

  int get materializedChildBase => _materializedChildBase;
  int _materializedChildBase;

  int get materializedChildCount => _materializedChildCount;
  int _materializedChildCount;

  double get startOffsetBase => _startOffsetBase;
  double _startOffsetBase;

  double get startOffsetLimit =>_startOffsetLimit;
  double _startOffsetLimit;

  void updateRenderObject(_VirtualListViewport oldWidget) {
    renderObject
      ..scrollDirection = widget.scrollDirection
      ..scrollAnchor = widget.scrollAnchor
      ..itemExtent = widget.itemExtent
      ..padding = widget.padding
      ..overlayPainter = widget.overlayPainter;
    super.updateRenderObject(oldWidget);
  }

  double _contentExtent;
  double _containerExtent;

  void layout(BoxConstraints constraints) {
    final int length = renderObject.virtualChildCount;
    final double itemExtent = widget.itemExtent;
    final EdgeDims padding = widget.padding ?? EdgeDims.zero;
    final Size containerSize = renderObject.size;

    double containerExtent;
    double contentExtent;

    switch (widget.scrollDirection) {
      case Axis.vertical:
        containerExtent = containerSize.height;
        contentExtent = length == null ? double.INFINITY : widget.itemExtent * length + padding.vertical;
        break;
      case Axis.horizontal:
        containerExtent = renderObject.size.width;
        contentExtent = length == null ? double.INFINITY : widget.itemExtent * length + padding.horizontal;
        break;
    }

    if (length == 0) {
      _materializedChildBase = 0;
      _materializedChildCount = 0;
      _startOffsetBase = 0.0;
      _startOffsetLimit = double.INFINITY;
    } else {
      final double startOffset = widget.startOffset;
      int startItem = math.max(0, startOffset ~/ itemExtent);
      int limitItem = math.max(0, ((startOffset + containerExtent) / itemExtent).ceil());

      if (!widget.itemsWrap && length != null) {
        startItem = math.min(length, startItem);
        limitItem = math.min(length, limitItem);
      }

      _materializedChildBase = startItem;
      _materializedChildCount = limitItem - startItem;
      _startOffsetBase = startItem * itemExtent;
      _startOffsetLimit = limitItem * itemExtent - containerExtent;

      if (widget.scrollAnchor == ViewportAnchor.end)
        _materializedChildBase = (length - _materializedChildBase - _materializedChildCount) % length;
    }

    Size materializedContentSize;
    switch (widget.scrollDirection) {
      case Axis.vertical:
        materializedContentSize = new Size(containerSize.width, _materializedChildCount * itemExtent);
        break;
      case Axis.horizontal:
        materializedContentSize = new Size(_materializedChildCount * itemExtent, containerSize.height);
        break;
    }
    renderObject.dimensions = new ViewportDimensions(containerSize: containerSize, contentSize: materializedContentSize);

    super.layout(constraints);

    if (contentExtent != _contentExtent || containerExtent != _containerExtent) {
      _contentExtent = contentExtent;
      _containerExtent = containerExtent;
      widget.onExtentsChanged(_contentExtent, _containerExtent);
    }
  }
}

class ListViewport extends _VirtualListViewport with VirtualViewportFromIterable {
  ListViewport({
    ExtentsChangedCallback onExtentsChanged,
    double scrollOffset: 0.0,
    Axis scrollDirection: Axis.vertical,
    ViewportAnchor scrollAnchor: ViewportAnchor.start,
    double itemExtent,
    bool itemsWrap: false,
    EdgeDims padding,
    Painter overlayPainter,
    this.children
  }) : super(
    onExtentsChanged,
    scrollOffset,
    scrollDirection,
    scrollAnchor,
    itemExtent,
    itemsWrap,
    padding,
    overlayPainter
  );

  final Iterable<Widget> children;
}

/// An optimized scrollable widget for a large number of children that are all
/// the same size (extent) in the scrollDirection. For example for
/// ScrollDirection.vertical itemExtent is the height of each item. Use this
/// widget when you have a large number of children or when you are concerned
// about offscreen widgets consuming resources.
class ScrollableLazyList extends Scrollable {
  ScrollableLazyList({
    Key key,
    double initialScrollOffset,
    Axis scrollDirection: Axis.vertical,
    ViewportAnchor scrollAnchor: ViewportAnchor.start,
    ScrollListener onScroll,
    SnapOffsetCallback snapOffsetCallback,
    this.itemExtent,
    this.itemCount,
    this.itemBuilder,
    this.padding,
    this.scrollableListPainter
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    scrollDirection: scrollDirection,
    scrollAnchor: scrollAnchor,
    onScroll: onScroll,
    snapOffsetCallback: snapOffsetCallback
  ) {
    assert(itemExtent != null);
    assert(itemBuilder != null);
    assert(itemCount != null || scrollAnchor == ViewportAnchor.start);
  }

  final double itemExtent;
  final int itemCount;
  final ItemListBuilder itemBuilder;
  final EdgeDims padding;
  final ScrollableListPainter scrollableListPainter;

  ScrollableState createState() => new _ScrollableLazyListState();
}

class _ScrollableLazyListState extends ScrollableState<ScrollableLazyList> {
  ScrollBehavior<double, double> createScrollBehavior() => new OverscrollBehavior();
  ExtentScrollBehavior get scrollBehavior => super.scrollBehavior;

  void _handleExtentsChanged(double contentExtent, double containerExtent) {
    config.scrollableListPainter?.contentExtent = contentExtent;
    setState(() {
      scrollTo(scrollBehavior.updateExtents(
        contentExtent: contentExtent,
        containerExtent: containerExtent,
        scrollOffset: scrollOffset
      ));
    });
  }

  void dispatchOnScrollStart() {
    super.dispatchOnScrollStart();
    config.scrollableListPainter?.scrollStarted();
  }

  void dispatchOnScroll() {
    super.dispatchOnScroll();
    config.scrollableListPainter?.scrollOffset = scrollOffset;
  }

  void dispatchOnScrollEnd() {
    super.dispatchOnScrollEnd();
    config.scrollableListPainter?.scrollEnded();
  }

  Widget buildContent(BuildContext context) {
    return new LazyListViewport(
      onExtentsChanged: _handleExtentsChanged,
      scrollOffset: scrollOffset,
      scrollDirection: config.scrollDirection,
      scrollAnchor: config.scrollAnchor,
      itemExtent: config.itemExtent,
      itemCount: config.itemCount,
      itemBuilder: config.itemBuilder,
      padding: config.padding,
      overlayPainter: config.scrollableListPainter
    );
  }
}

class LazyListViewport extends _VirtualListViewport with VirtualViewportFromBuilder {
  LazyListViewport({
    ExtentsChangedCallback onExtentsChanged,
    double scrollOffset: 0.0,
    Axis scrollDirection: Axis.vertical,
    ViewportAnchor scrollAnchor: ViewportAnchor.start,
    double itemExtent,
    EdgeDims padding,
    Painter overlayPainter,
    this.itemCount,
    this.itemBuilder
  }) : super(
    onExtentsChanged,
    scrollOffset,
    scrollDirection,
    scrollAnchor,
    itemExtent,
    false, // Don't support wrapping yet.
    padding,
    overlayPainter
  );

  final int itemCount;
  final ItemListBuilder itemBuilder;
}
