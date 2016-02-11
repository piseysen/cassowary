// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';

import 'package:vector_math/vector_math_64.dart';

/// An interpolation between two [BoxConstraint]s.
class BoxConstraintsTween extends Tween<BoxConstraints> {
  BoxConstraintsTween({ BoxConstraints begin, BoxConstraints end }) : super(begin: begin, end: end);

  BoxConstraints lerp(double t) => BoxConstraints.lerp(begin, end, t);
}

/// An interpolation between two [Decoration]s.
class DecorationTween extends Tween<Decoration> {
  DecorationTween({ Decoration begin, Decoration end }) : super(begin: begin, end: end);

  Decoration lerp(double t) {
    if (begin == null && end == null)
      return null;
    if (end == null)
      return begin.lerpTo(end, t);
    return end.lerpFrom(begin, t);
  }
}

/// An interpolation between two [EdgeDims]s.
class EdgeDimsTween extends Tween<EdgeDims> {
  EdgeDimsTween({ EdgeDims begin, EdgeDims end }) : super(begin: begin, end: end);

  EdgeDims lerp(double t) => EdgeDims.lerp(begin, end, t);
}

/// An interpolation between two [Matrix4]s.
///
/// Currently this class works only for translations.
class Matrix4Tween extends Tween<Matrix4> {
  Matrix4Tween({ Matrix4 begin, Matrix4 end }) : super(begin: begin, end: end);

  Matrix4 lerp(double t) {
    // TODO(mpcomplete): Animate the full matrix. Will animating the cells
    // separately work?
    Vector3 beginT = begin.getTranslation();
    Vector3 endT = end.getTranslation();
    Vector3 lerpT = beginT*(1.0-t) + endT*t;
    return new Matrix4.identity()..translate(lerpT);
  }
}

/// An abstract widget for building components that gradually change their
/// values over a period of time.
abstract class AnimatedWidgetBase extends StatefulComponent {
  AnimatedWidgetBase({
    Key key,
    this.curve: Curves.linear,
    this.duration
  }) : super(key: key) {
    assert(curve != null);
    assert(duration != null);
  }

  /// The curve to apply when animating the parameters of this container.
  final Curve curve;

  /// The duration over which to animate the parameters of this container.
  final Duration duration;

  AnimatedWidgetBaseState createState();

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('duration: ${duration.inMilliseconds}ms');
  }
}

/// Used by [AnimatedWidgetBaseState].
typedef Tween<T> TweenConstructor<T>(T targetValue);

/// Used by [AnimatedWidgetBaseState].
typedef Tween<T> TweenVisitor<T>(Tween<T> tween, T targetValue, TweenConstructor<T> constructor);

/// A base class for widgets with implicit animations.
abstract class AnimatedWidgetBaseState<T extends AnimatedWidgetBase> extends State<T> {
  AnimationController _controller;

  /// The animation driving this widget's implicit animations.
  Animation<double> get animation => _animation;
  Animation<double> _animation;

  void initState() {
    super.initState();
    _controller = new AnimationController(
      duration: config.duration,
      debugLabel: '${config.toStringShort()}'
    )..addListener(_handleAnimationChanged);
    _updateCurve();
    _constructTweens();
  }

  void didUpdateConfig(T oldConfig) {
    if (config.curve != oldConfig.curve)
      _updateCurve();
    _controller.duration = config.duration;
    if (_constructTweens()) {
      forEachTween((Tween tween, dynamic targetValue, TweenConstructor<T> constructor) {
        _updateTween(tween, targetValue);
        return tween;
      });
      _controller
        ..value = 0.0
        ..forward();
    }
  }

  void _updateCurve() {
    if (config.curve != null)
      _animation = new CurvedAnimation(parent: _controller, curve: config.curve);
    else
      _animation = _controller;
  }

  void dispose() {
    _controller.stop();
    super.dispose();
  }

  void _handleAnimationChanged() {
    setState(() { });
  }

  bool _shouldAnimateTween(Tween tween, dynamic targetValue) {
    return targetValue != (tween.end ?? tween.begin);
  }

  void _updateTween(Tween tween, dynamic targetValue) {
    if (tween == null)
      return;
    tween
      ..begin = tween.evaluate(_animation)
      ..end = targetValue;
  }

  bool _constructTweens() {
    bool shouldStartAnimation = false;
    forEachTween((Tween tween, dynamic targetValue, TweenConstructor<T> constructor) {
      if (targetValue != null) {
        tween ??= constructor(targetValue);
        if (_shouldAnimateTween(tween, targetValue))
          shouldStartAnimation = true;
      } else {
        tween = null;
      }
      return tween;
    });
    return shouldStartAnimation;
  }

  /// Subclasses must implement this function by running through the following
  /// steps for for each animatable facet in the class:
  ///
  /// 1. Call the visitor callback with three arguments, the first argument
  /// being the current value of the Tween<T> object that represents the
  /// tween (initially null), the second argument, of type T, being the value
  /// on the Widget (config) that represents the current target value of the
  /// tween, and the third being a callback that takes a value T (which will
  /// be the second argument to the visitor callback), and that returns an
  /// Tween<T> object for the tween, configured with the given value
  /// as the begin value.
  ///
  /// 2. Take the value returned from the callback, and store it. This is the
  /// value to use as the current value the next time that the forEachTween()
  /// method is called.
  void forEachTween(TweenVisitor visitor);
}

/// A container that gradually changes its values over a period of time.
///
/// This class is useful for generating simple implicit transitions between
/// different parameters to [Container]. For more complex animations, you'll
/// likely want to use a subclass of [Transition] or use an
/// [AnimationController] yourself.
class AnimatedContainer extends AnimatedWidgetBase {
  AnimatedContainer({
    Key key,
    this.child,
    this.constraints,
    this.decoration,
    this.foregroundDecoration,
    this.margin,
    this.padding,
    this.transform,
    this.width,
    this.height,
    Curve curve: Curves.linear,
    Duration duration
  }) : super(key: key, curve: curve, duration: duration) {
    assert(decoration == null || decoration.debugAssertValid());
    assert(foregroundDecoration == null || foregroundDecoration.debugAssertValid());
    assert(margin == null || margin.isNonNegative);
    assert(padding == null || padding.isNonNegative);
  }

  final Widget child;

  /// Additional constraints to apply to the child.
  final BoxConstraints constraints;

  /// The decoration to paint behind the child.
  final Decoration decoration;

  /// The decoration to paint in front of the child.
  final Decoration foregroundDecoration;

  /// Empty space to surround the decoration.
  final EdgeDims margin;

  /// Empty space to inscribe inside the decoration.
  final EdgeDims padding;

  /// The transformation matrix to apply before painting the container.
  final Matrix4 transform;

  /// If non-null, requires the decoration to have this width.
  final double width;

  /// If non-null, requires the decoration to have this height.
  final double height;

  _AnimatedContainerState createState() => new _AnimatedContainerState();

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (constraints != null)
      description.add('$constraints');
    if (decoration != null)
      description.add('has background');
    if (foregroundDecoration != null)
      description.add('has foreground');
    if (margin != null)
      description.add('margin: $margin');
    if (padding != null)
      description.add('padding: $padding');
    if (transform != null)
      description.add('has transform');
    if (width != null)
      description.add('width: $width');
    if (height != null)
      description.add('height: $height');
  }
}

class _AnimatedContainerState extends AnimatedWidgetBaseState<AnimatedContainer> {
  BoxConstraintsTween _constraints;
  DecorationTween _decoration;
  DecorationTween _foregroundDecoration;
  EdgeDimsTween _margin;
  EdgeDimsTween _padding;
  Matrix4Tween _transform;
  Tween<double> _width;
  Tween<double> _height;

  void forEachTween(TweenVisitor visitor) {
    // TODO(ianh): Use constructor tear-offs when it becomes possible
    _constraints = visitor(_constraints, config.constraints, (dynamic value) => new BoxConstraintsTween(begin: value));
    _decoration = visitor(_decoration, config.decoration, (dynamic value) => new DecorationTween(begin: value));
    _foregroundDecoration = visitor(_foregroundDecoration, config.foregroundDecoration, (dynamic value) => new DecorationTween(begin: value));
    _margin = visitor(_margin, config.margin, (dynamic value) => new EdgeDimsTween(begin: value));
    _padding = visitor(_padding, config.padding, (dynamic value) => new EdgeDimsTween(begin: value));
    _transform = visitor(_transform, config.transform, (dynamic value) => new Matrix4Tween(begin: value));
    _width = visitor(_width, config.width, (dynamic value) => new Tween<double>(begin: value));
    _height = visitor(_height, config.height, (dynamic value) => new Tween<double>(begin: value));
  }

  Widget build(BuildContext context) {
    return new Container(
      child: config.child,
      constraints: _constraints?.evaluate(animation),
      decoration: _decoration?.evaluate(animation),
      foregroundDecoration: _foregroundDecoration?.evaluate(animation),
      margin: _margin?.evaluate(animation),
      padding: _padding?.evaluate(animation),
      transform: _transform?.evaluate(animation),
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation)
    );
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (_constraints != null)
      description.add('has constraints');
    if (_decoration != null)
      description.add('has background');
    if (_foregroundDecoration != null)
      description.add('has foreground');
    if (_margin != null)
      description.add('has margin');
    if (_padding != null)
      description.add('has padding');
    if (_transform != null)
      description.add('has transform');
    if (_width != null)
      description.add('has width');
    if (_height != null)
      description.add('has height');
  }
}

/// Animated version of [Positioned] which automatically transitions the child's
/// position over a given duration whenever the given position changes.
///
/// Only works if it's the child of a [Stack].
class AnimatedPositioned extends AnimatedWidgetBase {
  AnimatedPositioned({
    Key key,
    this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    Curve curve: Curves.linear,
    Duration duration
  }) : super(key: key, curve: curve, duration: duration) {
    assert(left == null || right == null || width == null);
    assert(top == null || bottom == null || height == null);
  }

  AnimatedPositioned.fromRect({
    Key key,
    this.child,
    Rect rect,
    Curve curve: Curves.linear,
    Duration duration
  }) : left = rect.left,
       top = rect.top,
       width = rect.width,
       height = rect.height,
       right = null,
       bottom = null,
       super(key: key, curve: curve, duration: duration);

  final Widget child;

  /// The offset of the child's left edge from the left of the stack.
  final double left;

  /// The offset of the child's top edge from the top of the stack.
  final double top;

  /// The offset of the child's right edge from the right of the stack.
  final double right;

  /// The offset of the child's bottom edge from the bottom of the stack.
  final double bottom;

  /// The child's width.
  ///
  /// Only two out of the three horizontal values (left, right, width) can be
  /// set. The third must be null.
  final double width;

  /// The child's height.
  ///
  /// Only two out of the three vertical values (top, bottom, height) can be
  /// set. The third must be null.
  final double height;

  _AnimatedPositionedState createState() => new _AnimatedPositionedState();
}

class _AnimatedPositionedState extends AnimatedWidgetBaseState<AnimatedPositioned> {
  Tween<double> _left;
  Tween<double> _top;
  Tween<double> _right;
  Tween<double> _bottom;
  Tween<double> _width;
  Tween<double> _height;

  void forEachTween(TweenVisitor visitor) {
    // TODO(ianh): Use constructor tear-offs when it becomes possible
    _left = visitor(_left, config.left, (dynamic value) => new Tween<double>(begin: value));
    _top = visitor(_top, config.top, (dynamic value) => new Tween<double>(begin: value));
    _right = visitor(_right, config.right, (dynamic value) => new Tween<double>(begin: value));
    _bottom = visitor(_bottom, config.bottom, (dynamic value) => new Tween<double>(begin: value));
    _width = visitor(_width, config.width, (dynamic value) => new Tween<double>(begin: value));
    _height = visitor(_height, config.height, (dynamic value) => new Tween<double>(begin: value));
  }

  Widget build(BuildContext context) {
    return new Positioned(
      child: config.child,
      left: _left?.evaluate(animation),
      top: _top?.evaluate(animation),
      right: _right?.evaluate(animation),
      bottom: _bottom?.evaluate(animation),
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation)
    );
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (_left != null)
      description.add('has left');
    if (_top != null)
      description.add('has top');
    if (_right != null)
      description.add('has right');
    if (_bottom != null)
      description.add('has bottom');
    if (_width != null)
      description.add('has width');
    if (_height != null)
      description.add('has height');
  }
}
