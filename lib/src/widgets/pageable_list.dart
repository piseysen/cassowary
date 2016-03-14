// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderList, ViewportDimensions;

import 'basic.dart';
import 'framework.dart';
import 'scroll_behavior.dart';
import 'scrollable.dart';
import 'virtual_viewport.dart';

/// Controls how a pageable list should behave during a fling.
enum PageableListFlingBehavior {
  canFlingAcrossMultiplePages,
  stopAtNextPage
}

/// Scrollable widget that scrolls one "page" at a time.
///
/// In a pageable list, one child is visible at a time. Scrolling the list
/// reveals either the next or previous child.
class PageableList extends Scrollable {
  PageableList({
    Key key,
    double initialScrollOffset,
    Axis scrollDirection: Axis.vertical,
    ViewportAnchor scrollAnchor: ViewportAnchor.start,
    ScrollListener onScrollStart,
    ScrollListener onScroll,
    ScrollListener onScrollEnd,
    SnapOffsetCallback snapOffsetCallback,
    this.itemsWrap: false,
    this.itemsSnapAlignment: PageableListFlingBehavior.stopAtNextPage,
    this.onPageChanged,
    this.scrollableListPainter,
    this.duration: const Duration(milliseconds: 200),
    this.curve: Curves.ease,
    this.children
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    scrollDirection: scrollDirection,
    scrollAnchor: scrollAnchor,
    onScrollStart: onScrollStart,
    onScroll: onScroll,
    onScrollEnd: onScrollEnd,
    snapOffsetCallback: snapOffsetCallback
  ) {
    assert(itemsSnapAlignment != null);
  }

  /// Whether the first item should be revealed after scrolling past the last item.
  final bool itemsWrap;

  /// Controls whether a fling always reveals the adjacent item or whether flings can traverse many items.
  final PageableListFlingBehavior itemsSnapAlignment;

  /// Called when the currently visible page changes.
  final ValueChanged<int> onPageChanged;

  /// Used to paint the scrollbar for this list.
  final ScrollableListPainter scrollableListPainter;

  /// The duration used when animating to a given page.
  final Duration duration;

  /// The animation curve to use when animating to a given page.
  final Curve curve;

  /// The list of pages themselves.
  final Iterable<Widget> children;

  @override
  PageableListState<PageableList> createState() => new PageableListState<PageableList>();
}

/// State for a [PageableList] widget.
///
/// Widgets that subclass [PageableList] can subclass this class to have
/// sensible default behaviors for pageable lists.
class PageableListState<T extends PageableList> extends ScrollableState<T> {
  int get _itemCount => config.children?.length ?? 0;
  int _previousItemCount;

  double get _pixelsPerScrollUnit {
    final RenderBox box = context.findRenderObject();
    if (box == null || !box.hasSize)
      return 0.0;
    switch (config.scrollDirection) {
      case Axis.horizontal:
        return box.size.width;
      case Axis.vertical:
        return box.size.height;
    }
  }

  @override
  double pixelOffsetToScrollOffset(double pixelOffset) {
    final double pixelsPerScrollUnit = _pixelsPerScrollUnit;
    return super.pixelOffsetToScrollOffset(pixelsPerScrollUnit == 0.0 ? 0.0 : pixelOffset / pixelsPerScrollUnit);
  }

  @override
  double scrollOffsetToPixelOffset(double scrollOffset) {
    return super.scrollOffsetToPixelOffset(scrollOffset * _pixelsPerScrollUnit);
  }

  int _scrollOffsetToPageIndex(double scrollOffset) {
    int itemCount = _itemCount;
    if (itemCount == 0)
      return 0;
    int scrollIndex = scrollOffset.floor();
    switch (config.scrollAnchor) {
      case ViewportAnchor.start:
        return scrollIndex % itemCount;
      case ViewportAnchor.end:
        return (_itemCount - scrollIndex - 1) % itemCount;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateScrollBehavior();
  }

  @override
  void didUpdateConfig(PageableList oldConfig) {
    super.didUpdateConfig(oldConfig);

    bool scrollBehaviorUpdateNeeded = config.scrollDirection != oldConfig.scrollDirection;

    if (config.itemsWrap != oldConfig.itemsWrap)
      scrollBehaviorUpdateNeeded = true;

    if (_itemCount != _previousItemCount) {
      _previousItemCount = _itemCount;
      scrollBehaviorUpdateNeeded = true;
    }

    if (scrollBehaviorUpdateNeeded)
      _updateScrollBehavior();
  }

  void _updateScrollBehavior() {
    config.scrollableListPainter?.contentExtent = _itemCount.toDouble();
    scrollTo(scrollBehavior.updateExtents(
      contentExtent: _itemCount.toDouble(),
      containerExtent: 1.0,
      scrollOffset: scrollOffset
    ));
  }

  @override
  void dispatchOnScrollStart() {
    super.dispatchOnScrollStart();
    config.scrollableListPainter?.scrollStarted();
  }

  @override
  void dispatchOnScroll() {
    super.dispatchOnScroll();
    config.scrollableListPainter?.scrollOffset = scrollOffset;
  }

  @override
  void dispatchOnScrollEnd() {
    super.dispatchOnScrollEnd();
    config.scrollableListPainter?.scrollEnded();
  }

  @override
  Widget buildContent(BuildContext context) {
    return new PageViewport(
      itemsWrap: config.itemsWrap,
      mainAxis: config.scrollDirection,
      anchor: config.scrollAnchor,
      startOffset: scrollOffset,
      overlayPainter: config.scrollableListPainter,
      children: config.children
    );
  }

  UnboundedBehavior _unboundedBehavior;
  OverscrollBehavior _overscrollBehavior;

  @override
  ExtentScrollBehavior get scrollBehavior {
    if (config.itemsWrap) {
      _unboundedBehavior ??= new UnboundedBehavior();
      return _unboundedBehavior;
    }
    _overscrollBehavior ??= new OverscrollBehavior();
    return _overscrollBehavior;
  }

  @override
  ScrollBehavior<double, double> createScrollBehavior() => scrollBehavior;

  @override
  bool get shouldSnapScrollOffset => config.itemsSnapAlignment == PageableListFlingBehavior.canFlingAcrossMultiplePages;

  @override
  double snapScrollOffset(double newScrollOffset) {
    final double previousItemOffset = newScrollOffset.floorToDouble();
    final double nextItemOffset = newScrollOffset.ceilToDouble();
    return (newScrollOffset - previousItemOffset < 0.5 ? previousItemOffset : nextItemOffset)
      .clamp(scrollBehavior.minScrollOffset, scrollBehavior.maxScrollOffset);
  }

  Future<Null> _flingToAdjacentItem(double scrollVelocity) {
    final double newScrollOffset = snapScrollOffset(scrollOffset + scrollVelocity.sign)
      .clamp(snapScrollOffset(scrollOffset - 0.5), snapScrollOffset(scrollOffset + 0.5));
    return scrollTo(newScrollOffset, duration: config.duration, curve: config.curve)
      .then(_notifyPageChanged);
  }

  @override
  Future<Null> fling(double scrollVelocity) {
    switch(config.itemsSnapAlignment) {
      case PageableListFlingBehavior.canFlingAcrossMultiplePages:
        return super.fling(scrollVelocity).then(_notifyPageChanged);
      case PageableListFlingBehavior.stopAtNextPage:
        return _flingToAdjacentItem(scrollVelocity);
    }
  }

  @override
  Future<Null> settleScrollOffset() {
    return scrollTo(snapScrollOffset(scrollOffset), duration: config.duration, curve: config.curve)
      .then(_notifyPageChanged);
  }

  void _notifyPageChanged(_) {
    if (config.onPageChanged != null)
      config.onPageChanged(_scrollOffsetToPageIndex(scrollOffset));
  }
}

class PageViewport extends VirtualViewportFromIterable {
  PageViewport({
    this.startOffset: 0.0,
    this.mainAxis: Axis.vertical,
    this.anchor: ViewportAnchor.start,
    this.itemsWrap: false,
    this.overlayPainter,
    this.children
  }) {
    assert(mainAxis != null);
  }

  @override
  final double startOffset;

  final Axis mainAxis;
  final ViewportAnchor anchor;
  final bool itemsWrap;
  final RenderObjectPainter overlayPainter;

  @override
  final Iterable<Widget> children;

  @override
  RenderList createRenderObject(BuildContext context) => new RenderList();

  @override
  _PageViewportElement createElement() => new _PageViewportElement(this);
}

class _PageViewportElement extends VirtualViewportElement {
  _PageViewportElement(PageViewport widget) : super(widget);

  @override
  PageViewport get widget => super.widget;

  @override
  RenderList get renderObject => super.renderObject;

  @override
  int get materializedChildBase => _materializedChildBase;
  int _materializedChildBase;

  @override
  int get materializedChildCount => _materializedChildCount;
  int _materializedChildCount;

  @override
  double get startOffsetBase => _startOffsetBase;
  double _startOffsetBase;

  @override
  double get startOffsetLimit =>_startOffsetLimit;
  double _startOffsetLimit;

  @override
  double scrollOffsetToPixelOffset(double scrollOffset) {
    if (_containerExtent == null)
      return 0.0;
    return super.scrollOffsetToPixelOffset(scrollOffset) * _containerExtent;
  }

  @override
  void updateRenderObject(PageViewport oldWidget) {
    renderObject
      ..mainAxis = widget.mainAxis
      ..overlayPainter = widget.overlayPainter;
    super.updateRenderObject(oldWidget);
  }

  double _containerExtent;

  void _updateViewportDimensions() {
    final Size containerSize = renderObject.size;

    Size materializedContentSize;
    switch (widget.mainAxis) {
      case Axis.vertical:
        materializedContentSize = new Size(containerSize.width, _materializedChildCount * containerSize.height);
        break;
      case Axis.horizontal:
        materializedContentSize = new Size(_materializedChildCount * containerSize.width, containerSize.height);
        break;
    }
    renderObject.dimensions = new ViewportDimensions(containerSize: containerSize, contentSize: materializedContentSize);
  }

  @override
  void layout(BoxConstraints constraints) {
    final int length = renderObject.virtualChildCount;

    switch (widget.mainAxis) {
      case Axis.vertical:
        _containerExtent = renderObject.size.height;
        break;
      case Axis.horizontal:
        _containerExtent =  renderObject.size.width;
        break;
    }

    if (length == 0) {
      _materializedChildBase = 0;
      _materializedChildCount = 0;
      _startOffsetBase = 0.0;
      _startOffsetLimit = double.INFINITY;
    } else {
      int startItem = widget.startOffset.floor();
      int limitItem = (widget.startOffset + 1.0).ceil();

      if (!widget.itemsWrap) {
        startItem = startItem.clamp(0, length);
        limitItem = limitItem.clamp(0, length);
      }

      _materializedChildBase = startItem;
      _materializedChildCount = limitItem - startItem;
      _startOffsetBase = startItem.toDouble();
      _startOffsetLimit = (limitItem - 1).toDouble();
      if (widget.anchor == ViewportAnchor.end)
        _materializedChildBase = (length - _materializedChildBase - _materializedChildCount) % length;
    }

    _updateViewportDimensions();
    super.layout(constraints);
  }
}
