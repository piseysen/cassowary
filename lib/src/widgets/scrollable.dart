// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:newton/newton.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'homogeneous_viewport.dart';
import 'mixed_viewport.dart';
import 'navigator.dart';

// The gesture velocity properties are pixels/second, config min,max limits are pixels/ms
const double _kMillisecondsPerSecond = 1000.0;
const double _kMinFlingVelocity = -kMaxFlingVelocity * _kMillisecondsPerSecond;
const double _kMaxFlingVelocity = kMaxFlingVelocity * _kMillisecondsPerSecond;

typedef void ScrollListener(double scrollOffset);
typedef double SnapOffsetCallback(double scrollOffset);

/// A base class for scrollable widgets that reacts to user input and generates
/// a scrollOffset.
abstract class Scrollable extends StatefulComponent {
  Scrollable({
    Key key,
    this.initialScrollOffset,
    this.scrollDirection: ScrollDirection.vertical,
    this.onScrollStart,
    this.onScroll,
    this.onScrollEnd,
    this.snapOffsetCallback,
    this.snapAlignmentOffset: 0.0
  }) : super(key: key) {
    assert(scrollDirection == ScrollDirection.vertical ||
           scrollDirection == ScrollDirection.horizontal);
  }

  final double initialScrollOffset;
  final ScrollDirection scrollDirection;
  final ScrollListener onScrollStart;
  final ScrollListener onScroll;
  final ScrollListener onScrollEnd;
  final SnapOffsetCallback snapOffsetCallback;
  final double snapAlignmentOffset;
}

abstract class ScrollableState<T extends Scrollable> extends State<T> {
  void initState() {
    super.initState();
    _animation = new SimulationStepper(_setScrollOffset);
    _scrollOffset = Route.of(context)?.readState(context) ?? config.initialScrollOffset ?? 0.0;
  }

  SimulationStepper _animation;

  double get scrollOffset => _scrollOffset;
  double _scrollOffset;

  Offset get scrollOffsetVector {
    if (config.scrollDirection == ScrollDirection.horizontal)
      return new Offset(scrollOffset, 0.0);
    return new Offset(0.0, scrollOffset);
  }

  ScrollBehavior _scrollBehavior;
  ScrollBehavior createScrollBehavior();
  ScrollBehavior get scrollBehavior {
    if (_scrollBehavior == null)
      _scrollBehavior = createScrollBehavior();
    return _scrollBehavior;
  }

  GestureDragStartCallback _getDragStartHandler(ScrollDirection direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragStart;
  }

  GestureDragUpdateCallback _getDragUpdateHandler(ScrollDirection direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragUpdate;
  }

  GestureDragEndCallback _getDragEndHandler(ScrollDirection direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragEnd;
  }

  Widget build(BuildContext context) {
    return new GestureDetector(
      onVerticalDragStart: _getDragStartHandler(ScrollDirection.vertical),
      onVerticalDragUpdate: _getDragUpdateHandler(ScrollDirection.vertical),
      onVerticalDragEnd: _getDragEndHandler(ScrollDirection.vertical),
      onHorizontalDragStart: _getDragStartHandler(ScrollDirection.horizontal),
      onHorizontalDragUpdate: _getDragUpdateHandler(ScrollDirection.horizontal),
      onHorizontalDragEnd: _getDragEndHandler(ScrollDirection.horizontal),
      child: new Listener(
        child: buildContent(context),
        onPointerDown: _handlePointerDown
      )
    );
  }

  Widget buildContent(BuildContext context);

  Future _animateTo(double newScrollOffset, Duration duration, Curve curve) {
    _animation.stop();
    _animation.value = scrollOffset;
    return _animation.animateTo(newScrollOffset, duration: duration, curve: curve);
  }

  bool _scrollOffsetIsInBounds(double offset) {
    if (scrollBehavior is! ExtentScrollBehavior)
      return false;
    ExtentScrollBehavior behavior = scrollBehavior;
    return offset >= behavior.minScrollOffset && offset < behavior.maxScrollOffset;
  }

  Simulation _createFlingSimulation(double velocity) {
    return scrollBehavior.createFlingScrollSimulation(scrollOffset, velocity);
  }

  Simulation _createSnapSimulation(double velocity) {
    if (velocity == null || config.snapOffsetCallback == null || !_scrollOffsetIsInBounds(scrollOffset))
      return null;

    Simulation simulation = _createFlingSimulation(velocity);
    if (simulation == null)
        return null;

    double endScrollOffset = simulation.x(double.INFINITY);
    if (endScrollOffset.isNaN)
      return null;

    double snappedScrollOffset = config.snapOffsetCallback(endScrollOffset + config.snapAlignmentOffset);
    double alignedScrollOffset = snappedScrollOffset - config.snapAlignmentOffset;
    if (!_scrollOffsetIsInBounds(alignedScrollOffset))
      return null;

    double snapVelocity = velocity.abs() * (alignedScrollOffset - scrollOffset).sign;
    Simulation toSnapSimulation =
      scrollBehavior.createSnapScrollSimulation(scrollOffset, alignedScrollOffset, snapVelocity);
    if (toSnapSimulation == null)
      return null;

    double offsetMin = math.min(scrollOffset, alignedScrollOffset);
    double offsetMax = math.max(scrollOffset, alignedScrollOffset);
    return new ClampedSimulation(toSnapSimulation, xMin: offsetMin, xMax: offsetMax);
  }

  Future _startToEndAnimation({ double velocity }) {
    _animation.stop();
    Simulation simulation =
      _createSnapSimulation(velocity) ?? _createFlingSimulation(velocity ?? 0.0);
    if (simulation == null)
      return new Future.value();
    return _animation.animateWith(simulation);
  }

  void dispose() {
    _animation.stop();
    super.dispose();
  }

  void _setScrollOffset(double newScrollOffset) {
    if (_scrollOffset == newScrollOffset)
      return;
    setState(() {
      _scrollOffset = newScrollOffset;
    });
    Route.of(context)?.writeState(context, _scrollOffset);
    dispatchOnScroll();
  }

  Future scrollTo(double newScrollOffset, { Duration duration, Curve curve: Curves.ease }) {
    if (newScrollOffset == _scrollOffset)
      return new Future.value();

    if (duration == null) {
      _animation.stop();
      _setScrollOffset(newScrollOffset);
      return new Future.value();
    }

    return _animateTo(newScrollOffset, duration, curve);
  }

  Future scrollBy(double scrollDelta, { Duration duration, Curve curve }) {
    double newScrollOffset = scrollBehavior.applyCurve(_scrollOffset, scrollDelta);
    return scrollTo(newScrollOffset, duration: duration, curve: curve);
  }

  Future fling(Offset velocity) {
    if (velocity != Offset.zero)
      return _startToEndAnimation(velocity: _scrollVelocity(velocity));
    if (!_animation.isAnimating)
      return settleScrollOffset();
    return new Future.value();
  }

  Future settleScrollOffset() {
    return _startToEndAnimation();
  }

  void dispatchOnScrollStart() {
    if (config.onScrollStart != null)
      config.onScrollStart(_scrollOffset);
  }

  // Derived classes can override this method and call super.dispatchOnScroll()
  void dispatchOnScroll() {
    if (config.onScroll != null)
      config.onScroll(_scrollOffset);
  }

  void dispatchOnScrollEnd() {
    if (config.onScrollEnd != null)
      config.onScrollEnd(_scrollOffset);
  }

  double _scrollVelocity(ui.Offset velocity) {
    double scrollVelocity = config.scrollDirection == ScrollDirection.horizontal
      ? -velocity.dx
      : -velocity.dy;
    return scrollVelocity.clamp(_kMinFlingVelocity, _kMaxFlingVelocity) / _kMillisecondsPerSecond;
  }

  void _handlePointerDown(_) {
    _animation.stop();
  }

  void _handleDragStart() {
    scheduleMicrotask(dispatchOnScrollStart);
  }

  void _handleDragUpdate(double delta) {
    // We negate the delta here because a positive scroll offset moves the
    // the content up (or to the left) rather than down (or the right).
    scrollBy(-delta);
  }

  Future _handleDragEnd(Offset velocity) {
    return fling(velocity).then((_) {
        dispatchOnScrollEnd();
    });
  }
}

ScrollableState findScrollableAncestor(BuildContext context) {
  ScrollableState result;
  context.visitAncestorElements((Element element) {
    if (element is StatefulComponentElement) {
      if (element.state is ScrollableState) {
        result = element.state;
        return false;
      }
    }
    return true;
  });
  return result;
}

Future ensureWidgetIsVisible(BuildContext context, { Duration duration, Curve curve }) {
  assert(context.findRenderObject() is RenderBox);
  // TODO(abarth): This function doesn't handle nested scrollable widgets.

  ScrollableState scrollable = findScrollableAncestor(context);
  if (scrollable == null)
    return new Future.value();

  RenderBox targetBox = context.findRenderObject();
  assert(targetBox.attached);
  Size targetSize = targetBox.size;

  RenderBox scrollableBox = scrollable.context.findRenderObject();
  assert(scrollableBox.attached);
  Size scrollableSize = scrollableBox.size;

  double scrollOffsetDelta;
  switch (scrollable.config.scrollDirection) {
    case ScrollDirection.vertical:
      Point targetCenter = targetBox.localToGlobal(new Point(0.0, targetSize.height / 2.0));
      Point scrollableCenter = scrollableBox.localToGlobal(new Point(0.0, scrollableSize.height / 2.0));
      scrollOffsetDelta = targetCenter.y - scrollableCenter.y;
      break;
    case ScrollDirection.horizontal:
      Point targetCenter = targetBox.localToGlobal(new Point(targetSize.width / 2.0, 0.0));
      Point scrollableCenter = scrollableBox.localToGlobal(new Point(scrollableSize.width / 2.0, 0.0));
      scrollOffsetDelta = targetCenter.x - scrollableCenter.x;
      break;
    case ScrollDirection.both:
      assert(false); // See https://github.com/flutter/engine/issues/888
      break;
  }

  ExtentScrollBehavior scrollBehavior = scrollable.scrollBehavior;
  double scrollOffset = (scrollable.scrollOffset + scrollOffsetDelta)
    .clamp(scrollBehavior.minScrollOffset, scrollBehavior.maxScrollOffset);

  if (scrollOffset != scrollable.scrollOffset)
    return scrollable.scrollTo(scrollOffset, duration: duration, curve: curve);

  return new Future.value();
}

/// A simple scrollable widget that has a single child. Use this component if
/// you are not worried about offscreen widgets consuming resources.
class ScrollableViewport extends Scrollable {
  ScrollableViewport({
    Key key,
    this.child,
    double initialScrollOffset,
    ScrollDirection scrollDirection: ScrollDirection.vertical,
    ScrollListener onScroll
  }) : super(
    key: key,
    scrollDirection: scrollDirection,
    initialScrollOffset: initialScrollOffset,
    onScroll: onScroll
  );

  final Widget child;

  ScrollableViewportState createState() => new ScrollableViewportState();
}

class ScrollableViewportState extends ScrollableState<ScrollableViewport> {
  ScrollBehavior createScrollBehavior() => new OverscrollWhenScrollableBehavior();
  OverscrollWhenScrollableBehavior get scrollBehavior => super.scrollBehavior;

  double _viewportSize = 0.0;
  double _childSize = 0.0;
  void _handleViewportSizeChanged(Size newSize) {
    _viewportSize = config.scrollDirection == ScrollDirection.vertical ? newSize.height : newSize.width;
    setState(() {
      _updateScrollBehaviour();
    });
  }
  void _handleChildSizeChanged(Size newSize) {
    _childSize = config.scrollDirection == ScrollDirection.vertical ? newSize.height : newSize.width;
    setState(() {
      _updateScrollBehaviour();
    });
  }
  void _updateScrollBehaviour() {
    // if you don't call this from build(), you must call it from setState().
    scrollTo(scrollBehavior.updateExtents(
      contentExtent: _childSize,
      containerExtent: _viewportSize,
      scrollOffset: scrollOffset
    ));
  }

  Widget buildContent(BuildContext context) {
    return new SizeObserver(
      onSizeChanged: _handleViewportSizeChanged,
      child: new Viewport(
        scrollOffset: scrollOffsetVector,
        scrollDirection: config.scrollDirection,
        child: new SizeObserver(
          onSizeChanged: _handleChildSizeChanged,
          child: config.child
        )
      )
    );
  }
}

/// A mashup of [ScrollableViewport] and [BlockBody]. Useful when you have a small,
/// fixed number of children that you wish to arrange in a block layout and that
/// might exceed the height of its container (and therefore need to scroll).
class Block extends StatelessComponent {
  Block(this.children, {
    Key key,
    this.initialScrollOffset,
    this.scrollDirection: ScrollDirection.vertical,
    this.onScroll
  }) : super(key: key) {
    assert(!children.any((Widget child) => child == null));
  }

  final List<Widget> children;
  final double initialScrollOffset;
  final ScrollDirection scrollDirection;
  final ScrollListener onScroll;

  BlockDirection get _direction {
    if (scrollDirection == ScrollDirection.vertical)
      return BlockDirection.vertical;
    return BlockDirection.horizontal;
  }

  Widget build(BuildContext context) {
    return new ScrollableViewport(
      initialScrollOffset: initialScrollOffset,
      scrollDirection: scrollDirection,
      onScroll: onScroll,
      child: new BlockBody(children, direction: _direction)
    );
  }
}

abstract class ScrollableListPainter extends Painter {
  void attach(RenderObject renderObject) {
    assert(renderObject is RenderBlockViewport);
    super.attach(renderObject);
  }

  RenderBlockViewport get renderer => renderObject;

  bool get isVertical => renderer.isVertical;

  Size get viewportSize => renderer.size;

  double get contentExtent => _contentExtent;
  double _contentExtent = 0.0;
  void set contentExtent (double value) {
    assert(value != null);
    assert(value >= 0.0);
    if (_contentExtent == value)
      return;
    _contentExtent = value;
    renderer?.markNeedsPaint();
  }

  double get scrollOffset => _scrollOffset;
  double _scrollOffset = 0.0;
  void set scrollOffset (double value) {
    assert(value != null);
    if (_scrollOffset == value)
      return;
    _scrollOffset = value;
    renderer?.markNeedsPaint();
  }

  /// Called when a scroll starts. Subclasses may override this method to
  /// initialize some state or to play an animation. The returned Future should
  /// complete when the computation triggered by this method has finished.
  Future scrollStarted() => new Future.value();


  /// Similar to scrollStarted(). Called when a scroll ends. For fling scrolls
  /// "ended" means that the scroll animation either stopped of its own accord
  /// or was canceled  by the user.
  Future scrollEnded() => new Future.value();
}

/// An optimized scrollable widget for a large number of children that are all
/// the same size (extent) in the scrollDirection. For example for
/// ScrollDirection.vertical itemExtent is the height of each item. Use this
/// widget when you have a large number of children or when you are concerned
// about offscreen widgets consuming resources.
abstract class ScrollableWidgetList extends Scrollable {
  ScrollableWidgetList({
    Key key,
    double initialScrollOffset,
    ScrollDirection scrollDirection: ScrollDirection.vertical,
    ScrollListener onScroll,
    SnapOffsetCallback snapOffsetCallback,
    double snapAlignmentOffset: 0.0,
    this.itemsWrap: false,
    this.itemExtent,
    this.padding,
    this.scrollableListPainter
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    scrollDirection: scrollDirection,
    onScroll: onScroll,
    snapOffsetCallback: snapOffsetCallback,
    snapAlignmentOffset: snapAlignmentOffset
  ) {
    assert(itemExtent != null);
  }

  final bool itemsWrap;
  final double itemExtent;
  final EdgeDims padding;
  final ScrollableListPainter scrollableListPainter;
}

abstract class ScrollableWidgetListState<T extends ScrollableWidgetList> extends ScrollableState<T> {
  /// Subclasses must implement `get itemCount` to tell ScrollableWidgetList
  /// how many items there are in the list.
  int get itemCount;
  int _previousItemCount;

  Size _containerSize = Size.zero;

  void didUpdateConfig(T oldConfig) {
    super.didUpdateConfig(oldConfig);

    bool scrollBehaviorUpdateNeeded =
      config.padding != oldConfig.padding ||
      config.itemExtent != oldConfig.itemExtent ||
      config.scrollDirection != oldConfig.scrollDirection;

    if (config.itemsWrap != oldConfig.itemsWrap) {
      _scrollBehavior = null;
      scrollBehaviorUpdateNeeded = true;
    }

    if (itemCount != _previousItemCount) {
      _previousItemCount = itemCount;
      scrollBehaviorUpdateNeeded = true;
    }

    if (scrollBehaviorUpdateNeeded)
      _updateScrollBehavior();
  }

  ScrollBehavior createScrollBehavior() => new OverscrollBehavior();
  ExtentScrollBehavior get scrollBehavior => super.scrollBehavior;

  double get _containerExtent {
    return config.scrollDirection == ScrollDirection.vertical
      ? _containerSize.height
      : _containerSize.width;
  }

  void _handleSizeChanged(Size newSize) {
    setState(() {
      _containerSize = newSize;
      _updateScrollBehavior();
    });
  }

  double get _leadingPadding {
    EdgeDims padding = config.padding;
    if (config.scrollDirection == ScrollDirection.vertical)
      return padding != null ? padding.top : 0.0;
    return padding != null ? padding.left : -.0;
  }

  double get _trailingPadding {
    EdgeDims padding = config.padding;
    if (config.scrollDirection == ScrollDirection.vertical)
      return padding != null ? padding.bottom : 0.0;
    return padding != null ? padding.right : 0.0;
  }

  EdgeDims get _crossAxisPadding {
    EdgeDims padding = config.padding;
    if (padding == null)
      return null;
    if (config.scrollDirection == ScrollDirection.vertical)
      return new EdgeDims.only(left: padding.left, right: padding.right);
    return new EdgeDims.only(top: padding.top, bottom: padding.bottom);
  }

  double get _contentExtent {
    if (itemCount == null)
      return null;
    double contentExtent = config.itemExtent * itemCount;
    if (config.padding != null)
      contentExtent += _leadingPadding + _trailingPadding;
    return contentExtent;
  }

  void _updateScrollBehavior() {
    // if you don't call this from build(), you must call it from setState().
    if (config.scrollableListPainter != null)
      config.scrollableListPainter.contentExtent = _contentExtent;
    scrollTo(scrollBehavior.updateExtents(
      contentExtent: _contentExtent,
      containerExtent: _containerExtent,
      scrollOffset: scrollOffset
    ));
  }

  void dispatchOnScrollStart() {
    super.dispatchOnScrollStart();
    config.scrollableListPainter?.scrollStarted();
  }

  void dispatchOnScroll() {
    super.dispatchOnScroll();
    if (config.scrollableListPainter != null)
      config.scrollableListPainter.scrollOffset = scrollOffset;
  }

  void dispatchOnScrollEnd() {
    super.dispatchOnScrollEnd();
    config.scrollableListPainter?.scrollEnded();
  }

  Widget buildContent(BuildContext context) {
    if (itemCount != _previousItemCount) {
      _previousItemCount = itemCount;
      _updateScrollBehavior();
    }

    return new SizeObserver(
      onSizeChanged: _handleSizeChanged,
      child: new Container(
        padding: _crossAxisPadding,
        child: new HomogeneousViewport(
          builder: _buildItems,
          itemsWrap: config.itemsWrap,
          itemExtent: config.itemExtent,
          itemCount: itemCount,
          direction: config.scrollDirection,
          startOffset: scrollOffset - _leadingPadding,
          overlayPainter: config.scrollableListPainter
        )
      )
    );
  }

  List<Widget> _buildItems(BuildContext context, int start, int count) {
    List<Widget> result = buildItems(context, start, count);
    assert(result.every((Widget item) => item.key != null));
    return result;
  }

  List<Widget> buildItems(BuildContext context, int start, int count);

}

typedef Widget ItemBuilder<T>(BuildContext context, T item);

/// A wrapper around [ScrollableWidgetList] that helps you translate a list of
/// model objects into a scrollable list of widgets. Assumes all the widgets
/// have the same height.
class ScrollableList<T> extends ScrollableWidgetList {
  ScrollableList({
    Key key,
    double initialScrollOffset,
    ScrollDirection scrollDirection: ScrollDirection.vertical,
    ScrollListener onScroll,
    SnapOffsetCallback snapOffsetCallback,
    double snapAlignmentOffset: 0.0,
    this.items,
    this.itemBuilder,
    itemsWrap: false,
    double itemExtent,
    EdgeDims padding,
    ScrollableListPainter scrollableListPainter
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    scrollDirection: scrollDirection,
    onScroll: onScroll,
    snapOffsetCallback: snapOffsetCallback,
    snapAlignmentOffset: snapAlignmentOffset,
    itemsWrap: itemsWrap,
    itemExtent: itemExtent,
    padding: padding,
    scrollableListPainter: scrollableListPainter
  );

  final List<T> items;
  final ItemBuilder<T> itemBuilder;

  ScrollableListState<T, ScrollableList<T>> createState() => new ScrollableListState<T, ScrollableList<T>>();
}

class ScrollableListState<T, Config extends ScrollableList<T>> extends ScrollableWidgetListState<Config> {
  ScrollBehavior createScrollBehavior() {
    return config.itemsWrap ? new UnboundedBehavior() : super.createScrollBehavior();
  }

  int get itemCount => config.items.length;

  List<Widget> buildItems(BuildContext context, int start, int count) {
    List<Widget> result = new List<Widget>();
    int begin = config.itemsWrap ? start : math.max(0, start);
    int end = config.itemsWrap ? begin + count : math.min(begin + count, config.items.length);
    for (int i = begin; i < end; ++i)
      result.add(config.itemBuilder(context, config.items[i % itemCount]));
    return result;
  }
}

typedef void PageChangedCallback(int newPage);

class PageableList<T> extends ScrollableList<T> {
  PageableList({
    Key key,
    int initialPage,
    ScrollDirection scrollDirection: ScrollDirection.horizontal,
    ScrollListener onScroll,
    List<T> items,
    ItemBuilder<T> itemBuilder,
    bool itemsWrap: false,
    double itemExtent,
    this.onPageChanged,
    EdgeDims padding,
    this.duration: const Duration(milliseconds: 200),
    this.curve: Curves.ease
  }) : super(
    key: key,
    initialScrollOffset: initialPage == null ? null : initialPage * itemExtent,
    scrollDirection: scrollDirection,
    onScroll: onScroll,
    items: items,
    itemBuilder: itemBuilder,
    itemsWrap: itemsWrap,
    itemExtent: itemExtent,
    padding: padding
  );

  final Duration duration;
  final Curve curve;
  final PageChangedCallback onPageChanged;

  PageableListState<T> createState() => new PageableListState<T>();
}

class PageableListState<T> extends ScrollableListState<T, PageableList<T>> {
  double _snapScrollOffset(double newScrollOffset) {
    double scaledScrollOffset = newScrollOffset / config.itemExtent;
    double previousScrollOffset = scaledScrollOffset.floor() * config.itemExtent;
    double nextScrollOffset = scaledScrollOffset.ceil() * config.itemExtent;
    double delta = newScrollOffset - previousScrollOffset;
    return (delta < config.itemExtent / 2.0 ? previousScrollOffset : nextScrollOffset)
      .clamp(scrollBehavior.minScrollOffset, scrollBehavior.maxScrollOffset);
  }

  Future fling(ui.Offset velocity) {
    double scrollVelocity = _scrollVelocity(velocity);
    double newScrollOffset = _snapScrollOffset(scrollOffset + scrollVelocity.sign * config.itemExtent)
      .clamp(_snapScrollOffset(scrollOffset - config.itemExtent / 2.0),
             _snapScrollOffset(scrollOffset + config.itemExtent / 2.0));
    return scrollTo(newScrollOffset, duration: config.duration, curve: config.curve).then(_notifyPageChanged);
  }

  int get currentPage => (scrollOffset / config.itemExtent).floor() % itemCount;

  void _notifyPageChanged(_) {
    if (config.onPageChanged != null)
      config.onPageChanged(currentPage);
  }

  Future settleScrollOffset() {
    return scrollTo(_snapScrollOffset(scrollOffset), duration: config.duration, curve: config.curve).then(_notifyPageChanged);
  }
}

/// A general scrollable list for a large number of children that might not all
/// have the same height. Prefer [ScrollableWidgetList] when all the children
/// have the same height because it can use that property to be more efficient.
/// Prefer [ScrollableViewport] with a single child.
class ScrollableMixedWidgetList extends Scrollable {
  ScrollableMixedWidgetList({
    Key key,
    double initialScrollOffset,
    ScrollListener onScroll,
    SnapOffsetCallback snapOffsetCallback,
    double snapAlignmentOffset: 0.0,
    this.builder,
    this.token,
    this.onInvalidatorAvailable
  }) : super(
    key: key,
    initialScrollOffset: initialScrollOffset,
    onScroll: onScroll,
    snapOffsetCallback: snapOffsetCallback,
    snapAlignmentOffset: snapAlignmentOffset
  );

  final IndexedBuilder builder;
  final Object token;
  final InvalidatorAvailableCallback onInvalidatorAvailable;

  ScrollableMixedWidgetListState createState() => new ScrollableMixedWidgetListState();
}

class ScrollableMixedWidgetListState extends ScrollableState<ScrollableMixedWidgetList> {
  void initState() {
    super.initState();
    scrollBehavior.updateExtents(
      contentExtent: double.INFINITY
    );
  }

  ScrollBehavior createScrollBehavior() => new OverscrollBehavior();
  OverscrollBehavior get scrollBehavior => super.scrollBehavior;

  void _handleSizeChanged(Size newSize) {
    setState(() {
      scrollBy(scrollBehavior.updateExtents(
        containerExtent: newSize.height,
        scrollOffset: scrollOffset
      ));
    });
  }

  bool _contentChanged = false;

  void didUpdateConfig(ScrollableMixedWidgetList oldConfig) {
    super.didUpdateConfig(oldConfig);
    if (config.token != oldConfig.token) {
      // When the token changes the scrollable's contents may have changed.
      // Remember as much so that after the new contents have been laid out we
      // can adjust the scrollOffset so that the last page of content is still
      // visible.
      _contentChanged = true;
    }
  }

  void _handleExtentsUpdate(double newExtents) {
    double newScrollOffset;
    setState(() {
      newScrollOffset = scrollBehavior.updateExtents(
        contentExtent: newExtents ?? double.INFINITY,
        scrollOffset: scrollOffset
      );
    });
    if (_contentChanged) {
      _contentChanged = false;
      scrollTo(newScrollOffset);
    }
  }

  Widget buildContent(BuildContext context) {
    return new SizeObserver(
      onSizeChanged: _handleSizeChanged,
      child: new MixedViewport(
        startOffset: scrollOffset,
        builder: config.builder,
        token: config.token,
        onInvalidatorAvailable: config.onInvalidatorAvailable,
        onExtentsUpdate: _handleExtentsUpdate
      )
    );
  }
}
