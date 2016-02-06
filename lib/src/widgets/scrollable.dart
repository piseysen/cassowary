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
import 'notification_listener.dart';
import 'page_storage.dart';
import 'scroll_behavior.dart';

// The gesture velocity properties are pixels/second, config min,max limits are pixels/ms
const double _kMillisecondsPerSecond = 1000.0;
const double _kMinFlingVelocity = -kMaxFlingVelocity * _kMillisecondsPerSecond;
const double _kMaxFlingVelocity = kMaxFlingVelocity * _kMillisecondsPerSecond;

/// The accuracy to which scrolling is computed.
final Tolerance kPixelScrollTolerance = new Tolerance(
  velocity: 1.0 / (0.050 * ui.window.devicePixelRatio),  // logical pixels per second
  distance: 1.0 / ui.window.devicePixelRatio  // logical pixels
);

typedef void ScrollListener(double scrollOffset);
typedef double SnapOffsetCallback(double scrollOffset);

/// A base class for scrollable widgets.
///
/// Commonly used subclasses include [ScrollableList], [ScrollableGrid], and
/// [ScrollableViewport].
///
/// Widgets that subclass [Scrollable] typically use state objects that subclass
/// [ScrollableState].
abstract class Scrollable extends StatefulComponent {
  Scrollable({
    Key key,
    this.initialScrollOffset,
    this.scrollDirection: Axis.vertical,
    this.onScrollStart,
    this.onScroll,
    this.onScrollEnd,
    this.snapOffsetCallback,
    this.snapAlignmentOffset: 0.0
  }) : super(key: key) {
    assert(scrollDirection == Axis.vertical ||
           scrollDirection == Axis.horizontal);
  }

  /// The scroll offset this widget should use when first created.
  final double initialScrollOffset;

  /// The axis along which this widget should scroll.
  final Axis scrollDirection;

  /// Called whenever this widget starts to scroll.
  final ScrollListener onScrollStart;

  /// Called whenever this widget's scroll offset changes.
  final ScrollListener onScroll;

  /// Called whenever this widget stops scrolling.
  final ScrollListener onScrollEnd;

  /// Called to determine the offset to which scrolling should snap.
  final SnapOffsetCallback snapOffsetCallback;

  final double snapAlignmentOffset; // What does this do?

  /// The state from the closest instance of this class that encloses the given context.
  static ScrollableState of(BuildContext context) {
    return context.ancestorStateOfType(const TypeMatcher<ScrollableState>());
  }

  /// Scrolls the closest enclosing scrollable to make the given context visible.
  static Future ensureVisible(BuildContext context, { Duration duration, Curve curve: Curves.ease }) {
    assert(context.findRenderObject() is RenderBox);
    // TODO(abarth): This function doesn't handle nested scrollable widgets.

    ScrollableState scrollable = Scrollable.of(context);
    if (scrollable == null)
      return new Future.value();

    RenderBox targetBox = context.findRenderObject();
    assert(targetBox.attached);
    Size targetSize = targetBox.size;

    RenderBox scrollableBox = scrollable.context.findRenderObject();
    assert(scrollableBox.attached);
    Size scrollableSize = scrollableBox.size;

    double targetMin;
    double targetMax;
    double scrollableMin;
    double scrollableMax;

    switch (scrollable.config.scrollDirection) {
      case Axis.vertical:
        targetMin = targetBox.localToGlobal(Point.origin).y;
        targetMax = targetBox.localToGlobal(new Point(0.0, targetSize.height)).y;
        scrollableMin = scrollableBox.localToGlobal(Point.origin).y;
        scrollableMax = scrollableBox.localToGlobal(new Point(0.0, scrollableSize.height)).y;
        break;
      case Axis.horizontal:
        targetMin = targetBox.localToGlobal(Point.origin).x;
        targetMax = targetBox.localToGlobal(new Point(targetSize.width, 0.0)).x;
        scrollableMin = scrollableBox.localToGlobal(Point.origin).x;
        scrollableMax = scrollableBox.localToGlobal(new Point(scrollableSize.width, 0.0)).x;
        break;
    }

    double scrollOffsetDelta;
    if (targetMin < scrollableMin) {
      if (targetMax > scrollableMax) {
        // The target is to big to fit inside the scrollable. The best we can do
        // is to center the target.
        double targetCenter = (targetMin + targetMax) / 2.0;
        double scrollableCenter = (scrollableMin + scrollableMax) / 2.0;
        scrollOffsetDelta = targetCenter - scrollableCenter;
      } else {
        scrollOffsetDelta = targetMin - scrollableMin;
      }
    } else if (targetMax > scrollableMax) {
      scrollOffsetDelta = targetMax - scrollableMax;
    } else {
      return new Future.value();
    }

    ExtentScrollBehavior scrollBehavior = scrollable.scrollBehavior;
    double scrollOffset = (scrollable.scrollOffset + scrollOffsetDelta)
      .clamp(scrollBehavior.minScrollOffset, scrollBehavior.maxScrollOffset);

    if (scrollOffset != scrollable.scrollOffset)
      return scrollable.scrollTo(scrollOffset, duration: duration, curve: curve);

    return new Future.value();
  }

  ScrollableState createState();
}

/// Contains the state for common scrolling behaviors.
///
/// Widgets that subclass [Scrollable] typically use state objects that subclass
/// [ScrollableState].
abstract class ScrollableState<T extends Scrollable> extends State<T> {
  void initState() {
    super.initState();
    _controller = new AnimationController.unbounded()..addListener(_handleAnimationChanged);
    _scrollOffset = PageStorage.of(context)?.readState(context) ?? config.initialScrollOffset ?? 0.0;
  }

  AnimationController _controller;

  /// The current scroll offset.
  ///
  /// The scroll offset is applied to the child widget along the scroll
  /// direction before painting. A positive scroll offset indicates that
  /// more content in the preferred reading direction is visible.
  double get scrollOffset => _scrollOffset;
  double _scrollOffset;

  /// Convert a position or velocity measured in terms of pixels to a scrollOffset.
  /// Scrollable gesture handlers convert their incoming values with this method.
  /// Subclasses that define scrollOffset in units other than pixels must
  /// override this method.
  double pixelToScrollOffset(double pixelValue) => pixelValue;

  /// Returns the component of the given velocity in the scroll direction.
  double scrollDirectionVelocity(Offset scrollVelocity) {
    return config.scrollDirection == Axis.horizontal
      ? -scrollVelocity.dx
      : -scrollVelocity.dy;
  }

  ScrollBehavior _scrollBehavior;

  /// Subclasses should override this function to create the [ScrollBehavior]
  /// they desire.
  ScrollBehavior createScrollBehavior();

  /// The current scroll behavior of this widget.
  ///
  /// Scroll behaviors control where the boundaries of the scrollable are placed
  /// and how the scrolling physics should behave near those boundaries and
  /// after the user stops directly manipulating the scrollable.
  ScrollBehavior get scrollBehavior {
    if (_scrollBehavior == null)
      _scrollBehavior = createScrollBehavior();
    return _scrollBehavior;
  }

  GestureDragStartCallback _getDragStartHandler(Axis direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragStart;
  }

  GestureDragUpdateCallback _getDragUpdateHandler(Axis direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragUpdate;
  }

  GestureDragEndCallback _getDragEndHandler(Axis direction) {
    if (config.scrollDirection != direction || !scrollBehavior.isScrollable)
      return null;
    return _handleDragEnd;
  }

  Widget build(BuildContext context) {
    return new GestureDetector(
      onVerticalDragStart: _getDragStartHandler(Axis.vertical),
      onVerticalDragUpdate: _getDragUpdateHandler(Axis.vertical),
      onVerticalDragEnd: _getDragEndHandler(Axis.vertical),
      onHorizontalDragStart: _getDragStartHandler(Axis.horizontal),
      onHorizontalDragUpdate: _getDragUpdateHandler(Axis.horizontal),
      onHorizontalDragEnd: _getDragEndHandler(Axis.horizontal),
      behavior: HitTestBehavior.opaque,
      child: new Listener(
        child: buildContent(context),
        onPointerDown: _handlePointerDown
      )
    );
  }

  /// Subclasses should override this function to build the interior of their
  /// scrollable widget. Scrollable wraps the returned widget in a
  /// [GestureDetector] to observe the user's interaction with this widget and
  /// to adjust the scroll offset accordingly.
  Widget buildContent(BuildContext context);

  Future _animateTo(double newScrollOffset, Duration duration, Curve curve) {
    _controller.stop();
    _controller.value = scrollOffset;
    return _controller.animateTo(newScrollOffset, duration: duration, curve: curve);
  }

  bool _scrollOffsetIsInBounds(double offset) {
    if (scrollBehavior is! ExtentScrollBehavior)
      return false;
    ExtentScrollBehavior behavior = scrollBehavior;
    return offset >= behavior.minScrollOffset && offset < behavior.maxScrollOffset;
  }

  Simulation _createFlingSimulation(double velocity) {
    final Simulation simulation =  scrollBehavior.createFlingScrollSimulation(scrollOffset, velocity);
    if (simulation != null) {
      final double endVelocity = pixelToScrollOffset(kPixelScrollTolerance.velocity);
      final double endDistance = pixelToScrollOffset(kPixelScrollTolerance.distance);
      simulation.tolerance = new Tolerance(velocity: endVelocity.abs(), distance: endDistance);
    }
    return simulation;
  }

  /// Returns the snapped offset closest to the given scroll offset.
  double snapScrollOffset(double scrollOffset) {
    return config.snapOffsetCallback == null ? scrollOffset : config.snapOffsetCallback(scrollOffset);
  }

  /// Whether this scrollable should attempt to snap scroll offsets.
  bool get snapScrollOffsetChanges => config.snapOffsetCallback != null;

  Simulation _createSnapSimulation(double velocity) {
    if (!snapScrollOffsetChanges || velocity == 0.0 || !_scrollOffsetIsInBounds(scrollOffset))
      return null;

    Simulation simulation = _createFlingSimulation(velocity);
    if (simulation == null)
        return null;

    double endScrollOffset = simulation.x(double.INFINITY);
    if (endScrollOffset.isNaN)
      return null;

    double snappedScrollOffset = snapScrollOffset(endScrollOffset + config.snapAlignmentOffset);
    double alignedScrollOffset = snappedScrollOffset - config.snapAlignmentOffset;
    if (!_scrollOffsetIsInBounds(alignedScrollOffset))
      return null;

    double snapVelocity = velocity.abs() * (alignedScrollOffset - scrollOffset).sign;
    double endVelocity = pixelToScrollOffset(kPixelScrollTolerance.velocity * velocity.sign);
    Simulation toSnapSimulation =
      scrollBehavior.createSnapScrollSimulation(scrollOffset, alignedScrollOffset, snapVelocity, endVelocity);
    if (toSnapSimulation == null)
      return null;

    double offsetMin = math.min(scrollOffset, alignedScrollOffset);
    double offsetMax = math.max(scrollOffset, alignedScrollOffset);
    return new ClampedSimulation(toSnapSimulation, xMin: offsetMin, xMax: offsetMax);
  }

  Future _startToEndAnimation(Offset scrollVelocity) {
    double velocity = scrollDirectionVelocity(scrollVelocity);
    _controller.stop();
    Simulation simulation = _createSnapSimulation(velocity) ?? _createFlingSimulation(velocity);
    if (simulation == null)
      return new Future.value();
    return _controller.animateWith(simulation);
  }

  void dispose() {
    _controller.stop();
    super.dispose();
  }

  void _handleAnimationChanged() {
    _setScrollOffset(_controller.value);
  }

  void _setScrollOffset(double newScrollOffset) {
    if (_scrollOffset == newScrollOffset)
      return;
    setState(() {
      _scrollOffset = newScrollOffset;
    });
    PageStorage.of(context)?.writeState(context, _scrollOffset);
    new ScrollNotification(this, _scrollOffset).dispatch(context);
    dispatchOnScroll();
  }

  /// Scroll this widget to the given scroll offset.
  ///
  /// If a non-null [duration] is provided, the widget will animate to the new
  /// scroll offset over the given duration with the given curve.
  Future scrollTo(double newScrollOffset, { Duration duration, Curve curve: Curves.ease }) {
    if (newScrollOffset == _scrollOffset)
      return new Future.value();

    if (duration == null) {
      _controller.stop();
      _setScrollOffset(newScrollOffset);
      return new Future.value();
    }

    return _animateTo(newScrollOffset, duration, curve);
  }

  /// Scroll this widget by the given scroll delta.
  ///
  /// If a non-null [duration] is provided, the widget will animate to the new
  /// scroll offset over the given duration with the given curve.
  Future scrollBy(double scrollDelta, { Duration duration, Curve curve: Curves.ease }) {
    double newScrollOffset = scrollBehavior.applyCurve(_scrollOffset, scrollDelta);
    return scrollTo(newScrollOffset, duration: duration, curve: curve);
  }

  /// Fling the scroll offset with the given velocity.
  ///
  /// Calling this function starts a physics-based animation of the scroll
  /// offset with the given value as the initial velocity. The physics
  /// simulation used is determined by the scroll behavior.
  Future fling(Offset scrollVelocity) {
    if (scrollVelocity != Offset.zero)
      return _startToEndAnimation(scrollVelocity);
    if (!_controller.isAnimating)
      return settleScrollOffset();
    return new Future.value();
  }

  /// Animate the scroll offset to a value with a local minima of energy.
  ///
  /// Calling this function starts a physics-based animation of the scroll
  /// offset either to a snap point or to within the scrolling bounds. The
  /// physics simulation used is determined by the scroll behavior.
  Future settleScrollOffset() {
    return _startToEndAnimation(Offset.zero);
  }

  /// Calls the onScrollStart callback.
  ///
  /// Subclasses can override this function to hook the scroll start callback.
  void dispatchOnScrollStart() {
    if (config.onScrollStart != null)
      config.onScrollStart(_scrollOffset);
  }

  /// Calls the onScroll callback.
  ///
  /// Subclasses can override this function to hook the scroll callback.
  void dispatchOnScroll() {
    if (config.onScroll != null)
      config.onScroll(_scrollOffset);
  }

  /// Calls the dispatchOnScrollEnd callback.
  ///
  /// Subclasses can override this function to hook the scroll end callback.
  void dispatchOnScrollEnd() {
    if (config.onScrollEnd != null)
      config.onScrollEnd(_scrollOffset);
  }

  void _handlePointerDown(_) {
    _controller.stop();
  }

  void _handleDragStart(_) {
    scheduleMicrotask(dispatchOnScrollStart);
  }

  void _handleDragUpdate(double delta) {
    // We negate the delta here because a positive scroll offset moves the
    // the content up (or to the left) rather than down (or the right).
    scrollBy(pixelToScrollOffset(-delta));
  }

  double _toScrollVelocity(double velocity) {
    return pixelToScrollOffset(velocity.clamp(_kMinFlingVelocity, _kMaxFlingVelocity) / _kMillisecondsPerSecond);
  }

  Future _handleDragEnd(Offset pixelScrollVelocity) {
    final Offset scrollVelocity = new Offset(_toScrollVelocity(pixelScrollVelocity.dx), _toScrollVelocity(pixelScrollVelocity.dy));
    return fling(scrollVelocity).then((_) {
        dispatchOnScrollEnd();
    });
  }
}

/// Indicates that a descendant scrollable has scrolled.
class ScrollNotification extends Notification {
  ScrollNotification(this.scrollable, this.scrollOffset);

  /// The scrollable that scrolled.
  final ScrollableState scrollable;

  /// The new scroll offset that the scrollable obtained.
  final double scrollOffset;
}

/// A simple scrollable widget that has a single child. Use this component if
/// you are not worried about offscreen widgets consuming resources.
class ScrollableViewport extends Scrollable {
  ScrollableViewport({
    Key key,
    this.child,
    double initialScrollOffset,
    Axis scrollDirection: Axis.vertical,
    ScrollListener onScrollStart,
    ScrollListener onScroll,
    ScrollListener onScrollEnd
  }) : super(
    key: key,
    scrollDirection: scrollDirection,
    initialScrollOffset: initialScrollOffset,
    onScrollStart: onScrollStart,
    onScroll: onScroll,
    onScrollEnd: onScrollEnd
  );

  final Widget child;

  ScrollableState createState() => new _ScrollableViewportState();
}

class _ScrollableViewportState extends ScrollableState<ScrollableViewport> {
  ScrollBehavior createScrollBehavior() => new OverscrollWhenScrollableBehavior();
  OverscrollWhenScrollableBehavior get scrollBehavior => super.scrollBehavior;

  double _viewportSize = 0.0;
  double _childSize = 0.0;
  void _handleViewportSizeChanged(Size newSize) {
    _viewportSize = config.scrollDirection == Axis.vertical ? newSize.height : newSize.width;
    setState(() {
      _updateScrollBehavior();
    });
  }
  void _handleChildSizeChanged(Size newSize) {
    _childSize = config.scrollDirection == Axis.vertical ? newSize.height : newSize.width;
    setState(() {
      _updateScrollBehavior();
    });
  }
  void _updateScrollBehavior() {
    // if you don't call this from build(), you must call it from setState().
    scrollTo(scrollBehavior.updateExtents(
      contentExtent: _childSize,
      containerExtent: _viewportSize,
      scrollOffset: scrollOffset
    ));
  }

  Offset get _scrollOffsetVector {
    if (config.scrollDirection == Axis.horizontal)
      return new Offset(scrollOffset, 0.0);
    return new Offset(0.0, scrollOffset);
  }

  Widget buildContent(BuildContext context) {
    return new SizeObserver(
      onSizeChanged: _handleViewportSizeChanged,
      child: new Viewport(
        scrollOffset: _scrollOffsetVector,
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
  Block({
    Key key,
    this.children: const <Widget>[],
    this.padding,
    this.initialScrollOffset,
    this.scrollDirection: Axis.vertical,
    this.onScroll,
    this.scrollableKey
  }) : super(key: key) {
    assert(children != null);
    assert(!children.any((Widget child) => child == null));
  }

  final List<Widget> children;
  final EdgeDims padding;
  final double initialScrollOffset;
  final Axis scrollDirection;
  final ScrollListener onScroll;
  final Key scrollableKey;

  Widget build(BuildContext context) {
    Widget contents = new BlockBody(children: children, direction: scrollDirection);
    if (padding != null)
      contents = new Padding(padding: padding, child: contents);
    return new ScrollableViewport(
      key: scrollableKey,
      initialScrollOffset: initialScrollOffset,
      scrollDirection: scrollDirection,
      onScroll: onScroll,
      child: contents
    );
  }
}

abstract class ScrollableListPainter extends Painter {
  void attach(RenderObject renderObject) {
    assert(renderObject is RenderBox);
    assert(renderObject is HasScrollDirection);
    super.attach(renderObject);
  }

  RenderBox get renderObject => super.renderObject;

  Axis get scrollDirection {
    HasScrollDirection scrollable = renderObject as dynamic;
    return scrollable?.scrollDirection;
  }

  Size get viewportSize => renderObject.size;

  double get contentExtent => _contentExtent;
  double _contentExtent = 0.0;
  void set contentExtent (double value) {
    assert(value != null);
    assert(value >= 0.0);
    if (_contentExtent == value)
      return;
    _contentExtent = value;
    renderObject?.markNeedsPaint();
  }

  double get scrollOffset => _scrollOffset;
  double _scrollOffset = 0.0;
  void set scrollOffset (double value) {
    assert(value != null);
    if (_scrollOffset == value)
      return;
    _scrollOffset = value;
    renderObject?.markNeedsPaint();
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
    Axis scrollDirection: Axis.vertical,
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
    return config.scrollDirection == Axis.vertical
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
    if (config.scrollDirection == Axis.vertical)
      return padding != null ? padding.top : 0.0;
    return padding != null ? padding.left : -.0;
  }

  double get _trailingPadding {
    EdgeDims padding = config.padding;
    if (config.scrollDirection == Axis.vertical)
      return padding != null ? padding.bottom : 0.0;
    return padding != null ? padding.right : 0.0;
  }

  EdgeDims get _crossAxisPadding {
    EdgeDims padding = config.padding;
    if (padding == null)
      return null;
    if (config.scrollDirection == Axis.vertical)
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
