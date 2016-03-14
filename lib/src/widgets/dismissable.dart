// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'transitions.dart';
import 'framework.dart';
import 'gesture_detector.dart';

const Duration _kDismissDuration = const Duration(milliseconds: 200);
const Duration _kResizeDuration = const Duration(milliseconds: 300);
const Curve _kResizeTimeCurve = const Interval(0.4, 1.0, curve: Curves.ease);
const double _kMinFlingVelocity = 700.0;
const double _kMinFlingVelocityDelta = 400.0;
const double _kFlingVelocityScale = 1.0 / 300.0;
const double _kDismissThreshold = 0.4;

typedef void DismissDirectionCallback(DismissDirection direction);

/// The direction in which a [Dismissable] can be dismissed.
enum DismissDirection {
  /// The [Dismissable] can be dismissed by dragging either up or down.
  vertical,

  /// The [Dismissable] can be dismissed by dragging either left or right.
  horizontal,

  /// The [Dismissable] can be dismissed by dragging in the reverse of the
  /// reading direction (e.g., from right to left in left-to-right languages).
  endToStart,

  /// The [Dismissable] can be dismissed by dragging in the reading direction
  /// (e.g., from left to right in left-to-right languages).
  startToEnd,

  /// The [Dismissable] can be dismissed by dragging up only.
  up,

  /// The [Dismissable] can be dismissed by dragging down only.
  down
}

/// Can be dismissed by dragging in the indicated [direction].
///
/// Dragging or flinging this widget in the [DismissDirection] causes the child
/// to slide out of view. Following the slide animation, the Dismissable widget
/// animates its height (or width, whichever is perpendicular to the dismiss
/// direction) to zero.
///
/// Backgrounds can be used to implement the "leave-behind" idiom. If a background
/// is specified it is stacked behind the Dismissable's child and is exposed when
/// the child moves.
///
/// The [onDimissed] callback runs after Dismissable's size has collapsed to zero.
/// If the Dismissable is a list item, it must have a key that distinguishes it from
/// the other items and its onDismissed callback must remove the item from the list.
class Dismissable extends StatefulWidget {
  Dismissable({
    Key key,
    this.child,
    this.background,
    this.secondaryBackground,
    this.onResize,
    this.onDismissed,
    this.direction: DismissDirection.horizontal
  }) : super(key: key) {
    assert(key != null);
    assert(secondaryBackground != null ? background != null : true);
  }

  final Widget child;

  /// A widget that is stacked behind the child. If secondaryBackground is also
  /// specified then this widget only appears when the child has been dragged
  /// down or to the right.
  final  Widget background;

  /// A widget that is stacked behind the child and is exposed when the child
  /// has been dragged up or to the left. It may only be specified when background
  /// has also been specified.
  final Widget secondaryBackground;

  /// Called when the widget changes size (i.e., when contracting before being dismissed).
  final VoidCallback onResize;

  /// Called when the widget has been dismissed, after finishing resizing.
  final DismissDirectionCallback onDismissed;

  /// The direction in which the widget can be dismissed.
  final DismissDirection direction;

  @override
  _DismissableState createState() => new _DismissableState();
}

class _DismissableState extends State<Dismissable> {
  @override
  void initState() {
    super.initState();
    _moveController = new AnimationController(duration: _kDismissDuration)
      ..addStatusListener(_handleDismissStatusChanged);
    _updateMoveAnimation();
  }

  AnimationController _moveController;
  Animation<FractionalOffset> _moveAnimation;

  AnimationController _resizeController;
  Animation<double> _resizeAnimation;

  double _dragExtent = 0.0;
  bool _dragUnderway = false;

  @override
  void dispose() {
    _moveController?.stop();
    _resizeController?.stop();
    super.dispose();
  }

  bool get _directionIsXAxis {
    return config.direction == DismissDirection.horizontal
        || config.direction == DismissDirection.endToStart
        || config.direction == DismissDirection.startToEnd;
  }

  DismissDirection get _dismissDirection {
    if (_directionIsXAxis)
      return  _dragExtent > 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
    return _dragExtent > 0 ? DismissDirection.down : DismissDirection.up;
  }

  bool get _isActive {
    return _dragUnderway || _moveController.isAnimating;
  }

  Size _findSize() {
    RenderBox box = context.findRenderObject();
    assert(box != null);
    assert(box.hasSize);
    return box.size;
  }

  void _handleDragStart(_) {
    _dragUnderway = true;
    if (_moveController.isAnimating) {
      _dragExtent = _moveController.value * _findSize().width * _dragExtent.sign;
      _moveController.stop();
    } else {
      _dragExtent = 0.0;
      _moveController.value = 0.0;
    }
    setState(() {
      _updateMoveAnimation();
    });
  }

  void _handleDragUpdate(double delta) {
    if (!_isActive || _moveController.isAnimating)
      return;

    double oldDragExtent = _dragExtent;
    switch (config.direction) {
      case DismissDirection.horizontal:
      case DismissDirection.vertical:
        _dragExtent += delta;
        break;

      case DismissDirection.up:
      case DismissDirection.endToStart:
        if (_dragExtent + delta < 0)
          _dragExtent += delta;
        break;

      case DismissDirection.down:
      case DismissDirection.startToEnd:
        if (_dragExtent + delta > 0)
          _dragExtent += delta;
        break;
    }
    if (oldDragExtent.sign != _dragExtent.sign) {
      setState(() {
        _updateMoveAnimation();
      });
    }
    if (!_moveController.isAnimating) {
      _moveController.value = _dragExtent.abs() / (_directionIsXAxis ? _findSize().width : _findSize().height);
    }
  }

  void _updateMoveAnimation() {
    _moveAnimation = new Tween<FractionalOffset>(
      begin: FractionalOffset.zero,
      end: _directionIsXAxis ?
             new FractionalOffset(_dragExtent.sign, 0.0) :
             new FractionalOffset(0.0, _dragExtent.sign)
    ).animate(_moveController);
  }

  bool _isFlingGesture(Velocity velocity) {
    double vx = velocity.pixelsPerSecond.dx;
    double vy = velocity.pixelsPerSecond.dy;
    if (_directionIsXAxis) {
      if (vx.abs() - vy.abs() < _kMinFlingVelocityDelta)
        return false;
      switch(config.direction) {
        case DismissDirection.horizontal:
          return vx.abs() > _kMinFlingVelocity;
        case DismissDirection.endToStart:
          return -vx > _kMinFlingVelocity;
        default:
          return vx > _kMinFlingVelocity;
      }
    } else {
      if (vy.abs() - vx.abs() < _kMinFlingVelocityDelta)
        return false;
      switch(config.direction) {
        case DismissDirection.vertical:
          return vy.abs() > _kMinFlingVelocity;
        case DismissDirection.up:
          return -vy > _kMinFlingVelocity;
        default:
          return vy > _kMinFlingVelocity;
      }
    }
    return false;
  }

  void _handleDragEnd(Velocity velocity) {
    if (!_isActive || _moveController.isAnimating)
      return;
    _dragUnderway = false;
    if (_moveController.isCompleted) {
      _startResizeAnimation();
    } else if (_isFlingGesture(velocity)) {
      double flingVelocity = _directionIsXAxis ? velocity.pixelsPerSecond.dx : velocity.pixelsPerSecond.dy;
      _dragExtent = flingVelocity.sign;
      _moveController.fling(velocity: flingVelocity.abs() * _kFlingVelocityScale);
    } else if (_moveController.value > _kDismissThreshold) {
      _moveController.forward();
    } else {
      _moveController.reverse();
    }
  }

  void _handleDismissStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_dragUnderway)
      _startResizeAnimation();
  }

  void _startResizeAnimation() {
    assert(_moveController != null);
    assert(_moveController.isCompleted);
    assert(_resizeController == null);
    _resizeController = new AnimationController(duration: _kResizeDuration)
      ..addListener(_handleResizeProgressChanged);
    _resizeController.forward();
    setState(() {
      _resizeAnimation = new Tween<double>(
        begin: 1.0,
        end: 0.0
      ).animate(new CurvedAnimation(
        parent: _resizeController,
        curve: _kResizeTimeCurve
      ));
    });
  }

  void _handleResizeProgressChanged() {
    if (_resizeController.isCompleted) {
      if (config.onDismissed != null)
        config.onDismissed(_dismissDirection);
    } else {
      if (config.onResize != null)
        config.onResize();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget background = config.background;
    if (config.secondaryBackground != null) {
      final DismissDirection direction = _dismissDirection;
      if (direction == DismissDirection.endToStart || direction == DismissDirection.up)
        background = config.secondaryBackground;
    }

    if (_resizeAnimation != null) {
      // we've been dragged aside, and are now resizing.
      assert(() {
        if (_resizeAnimation.status != AnimationStatus.forward) {
          assert(_resizeAnimation.status == AnimationStatus.completed);
          throw new WidgetError(
            'A dismissed Dismissable widget is still part of the tree.\n' +
            'Make sure to implement the onDismissed handler and to immediately remove the Dismissable\n' +
            'widget from the application once that handler has fired.'
          );
        }
        return true;
      });

      return new SizeTransition(
        sizeFactor: _resizeAnimation,
        axis: _directionIsXAxis ? Axis.horizontal : Axis.vertical,
        child: background
      );
    }

    Widget backgroundAndChild = new SlideTransition(
      position: _moveAnimation,
      child: config.child
    );
    if (background != null) {
      backgroundAndChild = new Stack(
        children: <Widget>[
          new Positioned(left: 0.0, top: 0.0, bottom: 0.0, right: 0.0, child: background),
          new Viewport(child: backgroundAndChild)
        ]
      );
    }

    // We are not resizing but we may be being dragging in config.direction.
    return new GestureDetector(
      onHorizontalDragStart: _directionIsXAxis ? _handleDragStart : null,
      onHorizontalDragUpdate: _directionIsXAxis ? _handleDragUpdate : null,
      onHorizontalDragEnd: _directionIsXAxis ? _handleDragEnd : null,
      onVerticalDragStart: _directionIsXAxis ? null : _handleDragStart,
      onVerticalDragUpdate: _directionIsXAxis ? null : _handleDragUpdate,
      onVerticalDragEnd: _directionIsXAxis ? null : _handleDragEnd,
      behavior: HitTestBehavior.opaque,
      child: backgroundAndChild
    );
  }
}
