// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart';

import 'box.dart';
import 'debug.dart';
import 'object.dart';
import 'semantics.dart';

export 'package:flutter/gestures.dart' show
  PointerEvent,
  PointerDownEvent,
  PointerMoveEvent,
  PointerUpEvent,
  PointerCancelEvent;

/// A base class for render objects that resemble their children.
///
/// A proxy box has a single child and simply mimics all the properties of that
/// child by calling through to the child for each function in the render box
/// protocol. For example, a proxy box determines its size by askings its child
/// to layout with the same constraints and then matching the size.
///
/// A proxy box isn't useful on its own because you might as well just replace
/// the proxy box with its child. However, RenderProxyBox is a useful base class
/// for render objects that wish to mimic most, but not all, of the properties
/// of their child.
class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  /// Creates a proxy render box.
  ///
  /// Proxy render boxes are rarely created directly because they simply proxy
  /// the render box protocol to [child]. Instead, consider using one of the
  /// subclasses.
  RenderProxyBox([RenderBox child = null]) {
    this.child = child;
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicWidth(constraints);
    return super.getMinIntrinsicWidth(constraints);
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints);
    return super.getMaxIntrinsicWidth(constraints);
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicHeight(constraints);
    return super.getMinIntrinsicHeight(constraints);
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicHeight(constraints);
    return super.getMaxIntrinsicHeight(constraints);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null)
      return child.getDistanceToActualBaseline(baseline);
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, { Point position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child, offset);
  }
}

/// How to behave during hit tests.
enum HitTestBehavior {
  /// Targets that defer to their children receive events within their bounds
  /// only if one of their children is hit by the hit test.
  deferToChild,

  /// Opaque targets can be hit by hit tests, causing them to both receive
  /// events within their bounds and prevent targets visually behind them from
  /// also receiving events.
  opaque,

  /// Translucent targets both receive events within their bounds and permit
  /// targets visually behind them to also receive events.
  translucent,
}

/// A RenderProxyBox subclass that allows you to customize the
/// hit-testing behavior.
abstract class RenderProxyBoxWithHitTestBehavior extends RenderProxyBox {
  RenderProxyBoxWithHitTestBehavior({
    this.behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(child);

  HitTestBehavior behavior;

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    bool hitTarget = false;
    if (position.x >= 0.0 && position.x < size.width &&
        position.y >= 0.0 && position.y < size.height) {
      hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);
      if (hitTarget || behavior == HitTestBehavior.translucent)
        result.add(new BoxHitTestEntry(this, position));
    }
    return hitTarget;
  }

  @override
  bool hitTestSelf(Point position) => behavior == HitTestBehavior.opaque;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    switch (behavior) {
      case HitTestBehavior.translucent:
        description.add('behavior: translucent');
        break;
      case HitTestBehavior.opaque:
        description.add('behavior: opaque');
        break;
      case HitTestBehavior.deferToChild:
        description.add('behavior: defer-to-child');
        break;
    }
  }
}

/// Imposes additional constraints on its child.
///
/// A render constrained box proxies most functions in the render box protocol
/// to its child, except that when laying out its child, it tightens the
/// constraints provided by its parent by enforcing the [additionalConstraints]
/// as well.
///
/// For example, if you wanted [child] to have a minimum height of 50.0 logical
/// pixels, you could use `const BoxConstraints(minHeight: 50.0)`` as the
/// [additionalConstraints].
class RenderConstrainedBox extends RenderProxyBox {
  RenderConstrainedBox({
    RenderBox child,
    BoxConstraints additionalConstraints
  }) : _additionalConstraints = additionalConstraints, super(child) {
    assert(additionalConstraints != null);
    assert(additionalConstraints.debugAssertIsValid());
  }

  /// Additional constraints to apply to [child] during layout
  BoxConstraints get additionalConstraints => _additionalConstraints;
  BoxConstraints _additionalConstraints;
  set additionalConstraints (BoxConstraints newConstraints) {
    assert(newConstraints != null);
    assert(newConstraints.debugAssertIsValid());
    if (_additionalConstraints == newConstraints)
      return;
    _additionalConstraints = newConstraints;
    markNeedsLayout();
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicHeight(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainHeight(0.0);
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicHeight(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainHeight(0.0);
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(_additionalConstraints.enforce(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _additionalConstraints.enforce(constraints).constrain(Size.zero);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    assert(() {
      Paint paint;
      if (child == null || child.size.isEmpty) {
        paint = new Paint()
          ..color = debugPaintSpacingColor;
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    });
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('additionalConstraints: $additionalConstraints');
  }
}

/// Constrains the child's maxWidth and maxHeight if they're otherwise
/// unconstrained.
class RenderLimitedBox extends RenderProxyBox {
  RenderLimitedBox({
    RenderBox child,
    double maxWidth: double.INFINITY,
    double maxHeight: double.INFINITY
  }) : _maxWidth = maxWidth, _maxHeight = maxHeight, super(child) {
    assert(maxWidth != null && maxWidth >= 0.0);
    assert(maxHeight != null && maxHeight >= 0.0);
  }

  /// The value to use for maxWidth if the incoming maxWidth constraint is infinite.
  double get maxWidth => _maxWidth;
  double _maxWidth;
  set maxWidth (double value) {
    assert(value != null && value >= 0.0);
    if (_maxWidth == value)
      return;
    _maxWidth = value;
    markNeedsLayout();
  }

  /// The value to use for maxHeight if the incoming maxHeight constraint is infinite.
  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight (double value) {
    assert(value != null && value >= 0.0);
    if (_maxHeight == value)
      return;
    _maxHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _limitConstraints(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : constraints.constrainWidth(maxWidth),
      minHeight: constraints.minHeight,
      maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.constrainHeight(maxHeight)
    );
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicWidth(_limitConstraints(constraints));
    return _limitConstraints(constraints).constrainWidth(0.0);
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicWidth(_limitConstraints(constraints));
    return _limitConstraints(constraints).constrainWidth(0.0);
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMinIntrinsicHeight(_limitConstraints(constraints));
    return _limitConstraints(constraints).constrainHeight(0.0);
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child != null)
      return child.getMaxIntrinsicHeight(_limitConstraints(constraints));
    return _limitConstraints(constraints).constrainHeight(0.0);
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(_limitConstraints(constraints), parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = _limitConstraints(constraints).constrain(Size.zero);
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (maxWidth != double.INFINITY)
      description.add('maxWidth: $maxWidth');
    if (maxHeight != double.INFINITY)
      description.add('maxHeight: $maxHeight');
  }
}

/// Attempts to size the child to a specific aspect ratio.
///
/// The render object first tries the largest width permited by the layout
/// constraints. The height of the render object is determined by applying the
/// given aspect ratio to the width, expressed as a ratio of width to height.
///
/// For example, a 16:9 width:height aspect ratio would have a value of
/// 16.0/9.0. If the maximum width is infinite, the initial width is determined
/// by applying the aspect ratio to the maximum height.
///
/// Now consider a second example, this time with an aspect ratio of 2.0 and
/// layout constraints that require the width to be between 0.0 and 100.0 and
/// the height to be between 0.0 and 100.0. We'll select a width of 100.0 (the
/// biggest allowed) and a height of 50.0 (to match the aspect ratio).
///
/// In that same situation, if the aspect ratio is 0.5, we'll also select a
/// width of 100.0 (still the biggest allowed) and we'll attempt to use a height
/// of 200.0. Unfortunately, that violates the constraints because the child can
/// be at most 100.0 pixels tall. The render object will then take that value
/// and apply the aspect ratio again to obtain a width of 50.0. That width is
/// permitted by the constraints and the child receives a width of 50.0 and a
/// height of 100.0. If the width were not permitted, the render object would
/// continue iterating through the constraints. If the render object does not
/// find a feasible size after consulting each constraint, the render object
/// will eventually select a size for the child that meets the layout
/// constraints but fails to meet the aspect ratio constraints.
class RenderAspectRatio extends RenderProxyBox {
  RenderAspectRatio({
    RenderBox child,
    double aspectRatio
  }) : _aspectRatio = aspectRatio, super(child) {
    assert(_aspectRatio > 0.0);
    assert(_aspectRatio.isFinite);
    assert(_aspectRatio != null);
  }

  /// The aspect ratio to attempt to use.
  ///
  /// The aspect ratio is expressed as a ratio of width to height. For example,
  /// a 16:9 width:height aspect ratio would have a value of 16.0/9.0.
  double get aspectRatio => _aspectRatio;
  double _aspectRatio;
  set aspectRatio (double newAspectRatio) {
    assert(newAspectRatio != null);
    assert(newAspectRatio > 0.0);
    assert(newAspectRatio.isFinite);
    if (_aspectRatio == newAspectRatio)
      return;
    _aspectRatio = newAspectRatio;
    markNeedsLayout();
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.minWidth;
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrainWidth(constraints.maxHeight * aspectRatio);
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.minHeight;
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrainHeight(constraints.maxWidth / aspectRatio);
  }

  Size _applyAspectRatio(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    assert(() {
      if (!constraints.hasBoundedWidth && !constraints.hasBoundedHeight) {
        throw new FlutterError(
          '$runtimeType has unbounded constraints.\n'
          'This $runtimeType was given an aspect ratio of $aspectRatio but was given '
          'both unbounded width and unbounded height constraints. Because both '
          'constraints were unbounded, this render object doesn\'t know how much '
          'size to consume.'
        );
      }
      return true;
    });

    if (constraints.isTight)
      return constraints.smallest;

    double width = constraints.maxWidth;
    double height;

    // We default to picking the height based on the width, but if the width
    // would be infinite, that's not sensible so we try to infer the height
    // from the width.
    if (width.isFinite) {
      height = width / _aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    // Similar to RenderImage, we iteratively attempt to fit within the given
    // constraings while maintaining the given aspect ratio. The order of
    // applying the constraints is also biased towards inferring the height
    // from the width.

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / _aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / _aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * _aspectRatio;
    }

    return constraints.constrain(new Size(width, height));
  }

  @override
  void performLayout() {
    size = _applyAspectRatio(constraints);
    if (child != null)
      child.layout(new BoxConstraints.tight(size));
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('aspectRatio: $aspectRatio');
  }
}

/// Sizes its child to the child's intrinsic width.
///
/// Sizes its child's width to the child's maximum intrinsic width. If
/// [stepWidth] is non-null, the child's width will be snapped to a multiple of
/// the [stepWidth]. Similarly, if [stepHeight] is non-null, the child's height
/// will be snapped to a multiple of the [stepHeight].
///
/// This class is useful, for example, when unlimited width is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable width.
///
/// This class is relatively expensive. Avoid using it where possible.
class RenderIntrinsicWidth extends RenderProxyBox {

  RenderIntrinsicWidth({
    double stepWidth,
    double stepHeight,
    RenderBox child
  }) : _stepWidth = stepWidth, _stepHeight = stepHeight, super(child);

  /// If non-null, force the child's width to be a multiple of this value.
  double get stepWidth => _stepWidth;
  double _stepWidth;
  set stepWidth(double newStepWidth) {
    if (newStepWidth == _stepWidth)
      return;
    _stepWidth = newStepWidth;
    markNeedsLayout();
  }

  /// If non-null, force the child's height to be a multiple of this value.
  double get stepHeight => _stepHeight;
  double _stepHeight;
  set stepHeight(double newStepHeight) {
    if (newStepHeight == _stepHeight)
      return;
    _stepHeight = newStepHeight;
    markNeedsLayout();
  }

  static double _applyStep(double input, double step) {
    if (step == null)
      return input;
    return (input / step).ceil() * step;
  }

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    assert(child != null);
    if (constraints.hasTightWidth)
      return constraints;
    double width = child.getMaxIntrinsicWidth(constraints);
    assert(width == constraints.constrainWidth(width));
    return constraints.tighten(width: _applyStep(width, _stepWidth));
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return getMaxIntrinsicWidth(constraints);
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMaxIntrinsicWidth(constraints);
    assert(!childResult.isInfinite);
    return constraints.constrainWidth(_applyStep(childResult, _stepWidth));
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    assert(!childResult.isInfinite);
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    assert(!childResult.isInfinite);
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

  @override
  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = _getInnerConstraints(constraints);
      if (_stepHeight != null)
        childConstraints.tighten(height: getMaxIntrinsicHeight(childConstraints));
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('stepWidth: $stepWidth');
    description.add('stepHeight: $stepHeight');
  }
}

/// Sizes its child to the child's intrinsic height.
///
/// This class is useful, for example, when unlimited height is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable height.
///
/// This class is relatively expensive. Avoid using it where possible.
class RenderIntrinsicHeight extends RenderProxyBox {

  RenderIntrinsicHeight({
    RenderBox child
  }) : super(child);

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    assert(child != null);
    if (constraints.hasTightHeight)
      return constraints;
    double height = child.getMaxIntrinsicHeight(constraints);
    assert(height == constraints.constrainHeight(height));
    return constraints.tighten(height: height);
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMinIntrinsicWidth(_getInnerConstraints(constraints));
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMaxIntrinsicWidth(_getInnerConstraints(constraints));
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return getMaxIntrinsicHeight(constraints);
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    if (child == null)
      return constraints.constrainHeight(0.0);
    return child.getMaxIntrinsicHeight(constraints);
  }

  @override
  void performLayout() {
    if (child != null) {
      child.layout(_getInnerConstraints(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

}

int _getAlphaFromOpacity(double opacity) => (opacity * 255).round();

/// Makes its child partially transparent.
///
/// This class paints its child into an intermediate buffer and then blends the
/// child back into the scene partially transparent.
///
/// For values of opacity other than 0.0 and 1.0, this class is relatively
/// expensive because it requires painting the child into an intermediate
/// buffer. For the value 0.0, the child is simply not painted at all. For the
/// value 1.0, the child is painted immediately without an intermediate buffer.
class RenderOpacity extends RenderProxyBox {
  RenderOpacity({ RenderBox child, double opacity: 1.0 })
    : _opacity = opacity, _alpha = _getAlphaFromOpacity(opacity), super(child) {
    assert(opacity != null);
    assert(opacity >= 0.0 && opacity <= 1.0);
  }

  @override
  bool get alwaysNeedsCompositing => child != null && (_alpha != 0 && _alpha != 255);

  /// The fraction to scale the child's alpha value.
  ///
  /// An opacity of 1.0 is fully opaque. An opacity of 0.0 is fully transparent
  /// (i.e., invisible).
  ///
  /// The opacity must not be null.
  ///
  /// Values 1.0 and 0.0 are painted with a fast path. Other values
  /// require painting the child into an intermediate buffer, which is
  /// expensive.
  double get opacity => _opacity;
  double _opacity;
  set opacity (double newOpacity) {
    assert(newOpacity != null);
    assert(newOpacity >= 0.0 && newOpacity <= 1.0);
    if (_opacity == newOpacity)
      return;
    _opacity = newOpacity;
    _alpha = _getAlphaFromOpacity(_opacity);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int _alpha;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (_alpha == 0)
        return;
      if (_alpha == 255) {
        context.paintChild(child, offset);
        return;
      }
      assert(needsCompositing);
      context.pushOpacity(offset, _alpha, super.paint);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && _alpha != 0)
      visitor(child);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('opacity: ${opacity.toStringAsFixed(1)}');
  }
}

typedef Shader ShaderCallback(Rect bounds);

class RenderShaderMask extends RenderProxyBox {
  RenderShaderMask({ RenderBox child, ShaderCallback shaderCallback, TransferMode transferMode })
    : _shaderCallback = shaderCallback, _transferMode = transferMode, super(child);

  ShaderCallback get shaderCallback => _shaderCallback;
  ShaderCallback _shaderCallback;
  set shaderCallback (ShaderCallback newShaderCallback) {
    assert(newShaderCallback != null);
    if (_shaderCallback == newShaderCallback)
      return;
    _shaderCallback = newShaderCallback;
    markNeedsPaint();
  }

  TransferMode get transferMode => _transferMode;
  TransferMode _transferMode;
  set transferMode (TransferMode newTransferMode) {
    assert(newTransferMode != null);
    if (_transferMode == newTransferMode)
      return;
    _transferMode = newTransferMode;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      Rect rect = Point.origin & size;
      context.pushShaderMask(offset, _shaderCallback(rect), rect, _transferMode, super.paint);
    }
  }
}

class RenderBackdropFilter extends RenderProxyBox {
  RenderBackdropFilter({ RenderBox child, ui.ImageFilter filter })
    : _filter = filter, super(child) {
    assert(filter != null);
  }

  ui.ImageFilter get filter => _filter;
  ui.ImageFilter _filter;
  set filter (ui.ImageFilter newFilter) {
    assert(newFilter != null);
    if (_filter == newFilter)
      return;
    _filter = newFilter;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      context.pushBackdropFilter(offset, _filter, super.paint);
    }
  }
}

/// A class that provides custom clips.
abstract class CustomClipper<T> {
  /// Returns a description of the clip given that the render object being
  /// clipped is of the given size.
  T getClip(Size size);

  /// Returns an approximation of the clip returned by [getClip], as
  /// an axis-aligned Rect. This is used by the semantics layer to
  /// determine whether widgets should be excluded.
  ///
  /// By default, this returns a rectangle that is the same size as
  /// the RenderObject. If getClip returns a shape that is roughly the
  /// same size as the RenderObject (e.g. it's a rounded rectangle
  /// with very small arcs in the corners), then this may be adequate.
  Rect getApproximateClipRect(Size size) => Point.origin & size;

  /// Returns `true` if the new instance will result in a different clip
  /// than the oldClipper instance.
  bool shouldRepaint(CustomClipper<T> oldClipper);
}

abstract class _RenderCustomClip<T> extends RenderProxyBox {
  _RenderCustomClip({
    RenderBox child,
    CustomClipper<T> clipper
  }) : _clipper = clipper, super(child);

  /// If non-null, determines which clip to use on the child.
  CustomClipper<T> get clipper => _clipper;
  CustomClipper<T> _clipper;
  set clipper (CustomClipper<T> newClipper) {
    if (_clipper == newClipper)
      return;
    CustomClipper<T> oldClipper = _clipper;
    _clipper = newClipper;
    if (newClipper == null) {
      assert(oldClipper != null);
      markNeedsPaint();
      markNeedsSemanticsUpdate(onlyChanges: true);
    } else if (oldClipper == null ||
        oldClipper.runtimeType != oldClipper.runtimeType ||
        newClipper.shouldRepaint(oldClipper)) {
      markNeedsPaint();
      markNeedsSemanticsUpdate(onlyChanges: true);
    }
  }

  T get _defaultClip;
  T _clip;

  @override
  void performLayout() {
    super.performLayout();
    _clip = _clipper?.getClip(size) ?? _defaultClip;
  }

  @override
  Rect describeApproximatePaintClip(RenderObject child) => _clipper?.getApproximateClipRect(size) ?? Point.origin & size;
}

/// Clips its child using a rectangle.
///
/// Prevents its child from painting outside its bounds.
class RenderClipRect extends _RenderCustomClip<Rect> {
  RenderClipRect({
    RenderBox child,
    CustomClipper<Rect> clipper
  }) : super(child: child, clipper: clipper);

  @override
  Rect get _defaultClip => Point.origin & size;

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    if (_clipper != null) {
      Rect clipRect = _clip;
      if (!clipRect.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.pushClipRect(needsCompositing, offset, _clip, super.paint);
  }
}

/// Clips its child using a rounded rectangle.
///
/// Creates a rounded rectangle from its layout dimensions and the given x and
/// y radius values and prevents its child from painting outside that rounded
/// rectangle.
class RenderClipRRect extends RenderProxyBox {
  RenderClipRRect({
    RenderBox child,
    double xRadius,
    double yRadius
  }) : _xRadius = xRadius, _yRadius = yRadius, super(child) {
    assert(_xRadius != null);
    assert(_yRadius != null);
  }

  /// The radius of the rounded corners in the horizontal direction in logical pixels.
  ///
  /// Values are clamped to be between zero and half the width of the render
  /// object.
  double get xRadius => _xRadius;
  double _xRadius;
  set xRadius (double newXRadius) {
    assert(newXRadius != null);
    if (_xRadius == newXRadius)
      return;
    _xRadius = newXRadius;
    markNeedsPaint();
  }

  /// The radius of the rounded corners in the vertical direction in logical pixels.
  ///
  /// Values are clamped to be between zero and half the height of the render
  /// object.
  double get yRadius => _yRadius;
  double _yRadius;
  set yRadius (double newYRadius) {
    assert(newYRadius != null);
    if (_yRadius == newYRadius)
      return;
    _yRadius = newYRadius;
    markNeedsPaint();
  }

  // TODO(ianh): either convert this to the CustomClipper world, or
  // TODO(ianh): implement describeApproximatePaintClip for this class

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Rect rect = Point.origin & size;
      RRect rrect = new RRect.fromRectXY(rect, xRadius, yRadius);
      context.pushClipRRect(needsCompositing, offset, rect, rrect, super.paint);
    }
  }
}

/// Clips its child using an oval.
///
/// Inscribes an oval into its layout dimensions and prevents its child from
/// painting outside that oval.
class RenderClipOval extends _RenderCustomClip<Rect> {
  RenderClipOval({
    RenderBox child,
    CustomClipper<Rect> clipper
  }) : super(child: child, clipper: clipper);

  Rect _cachedRect;
  Path _cachedPath;

  Path _getClipPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = new Path()..addOval(_cachedRect);
    }
    return _cachedPath;
  }

  @override
  Rect get _defaultClip => Point.origin & size;

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    Rect clipBounds = _clip;
    Point center = clipBounds.center;
    // convert the position to an offset from the center of the unit circle
    Offset offset = new Offset((position.x - center.x) / clipBounds.width,
                               (position.y - center.y) / clipBounds.height);
    // check if the point is outside the unit circle
    if (offset.distanceSquared > 0.25) // x^2 + y^2 > r^2
      return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Rect clipBounds = _clip;
      context.pushClipPath(needsCompositing, offset, clipBounds, _getClipPath(clipBounds), super.paint);
    }
  }
}

/// Clips its child using a path.
///
/// Takes a delegate whose primary method returns a path that should
/// be used to prevent the child from painting outside the path.
///
/// Clipping to a path is expensive. Certain shapes have more
/// optimized render objects:
///
///  * To clip to a rectangle, consider [RenderClipRect].
///  * To clip to an oval or circle, consider [RenderClipOval].
///  * To clip to a rounded rectangle, consider [RenderClipRRect].
class RenderClipPath extends _RenderCustomClip<Path> {
  RenderClipPath({
    RenderBox child,
    CustomClipper<Path> clipper
  }) : super(child: child, clipper: clipper);

  @override
  Path get _defaultClip => new Path()..addRect(Point.origin & size);

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    if (_clip == null || !_clip.contains(position))
      return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.pushClipPath(needsCompositing, offset, Point.origin & size, _clip, super.paint);
  }
}

/// Where to paint a box decoration.
enum DecorationPosition {
  /// Paint the box decoration behind the children.
  background,

  /// Paint the box decoration in front of the children.
  foreground,
}

/// Paints a [Decoration] either before or after its child paints.
class RenderDecoratedBox extends RenderProxyBox {
  /// Creates a decorated box.
  ///
  /// Both the [decoration] and the [position] arguments are required. By
  /// default the decoration paints behind the child.
  RenderDecoratedBox({
    Decoration decoration,
    DecorationPosition position: DecorationPosition.background,
    RenderBox child
  }) : _decoration = decoration,
       _position = position,
       super(child) {
    assert(decoration != null);
    assert(position != null);
  }

  BoxPainter _painter;

  /// What decoration to paint.
  ///
  /// Commonly a [BoxDecoration].
  Decoration get decoration => _decoration;
  Decoration _decoration;
  set decoration (Decoration newDecoration) {
    assert(newDecoration != null);
    if (newDecoration == _decoration)
      return;
    _removeListenerIfNeeded();
    _painter = null;
    _decoration = newDecoration;
    _addListenerIfNeeded();
    markNeedsPaint();
  }

  /// Whether to paint the box decoration behind or in front of the child.
  DecorationPosition get position => _position;
  DecorationPosition _position;
  set position (DecorationPosition newPosition) {
    assert(newPosition != null);
    if (newPosition == _position)
      return;
    _position = newPosition;
    markNeedsPaint();
  }

  bool get _needsListeners {
    return attached && _decoration.needsListeners;
  }

  void _addListenerIfNeeded() {
    if (_needsListeners)
      _decoration.addChangeListener(markNeedsPaint);
  }

  void _removeListenerIfNeeded() {
    if (_needsListeners)
      _decoration.removeChangeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _addListenerIfNeeded();
  }

  @override
  void detach() {
    _removeListenerIfNeeded();
    super.detach();
  }

  @override
  bool hitTestSelf(Point position) {
    return _decoration.hitTest(size, position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(size.width != null);
    assert(size.height != null);
    _painter ??= _decoration.createBoxPainter();
    if (position == DecorationPosition.background)
      _painter.paint(context.canvas, offset & size);
    super.paint(context, offset);
    if (position == DecorationPosition.foreground)
      _painter.paint(context.canvas, offset & size);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('decoration:');
    description.addAll(_decoration.toString("  ").split('\n'));
  }
}

/// Applies a transformation before painting its child.
class RenderTransform extends RenderProxyBox {
  RenderTransform({
    Matrix4 transform,
    Offset origin,
    FractionalOffset alignment,
    this.transformHitTests: true,
    RenderBox child
  }) : super(child) {
    assert(transform != null);
    assert(alignment == null || (alignment.dx != null && alignment.dy != null));
    this.transform = transform;
    this.alignment = alignment;
    this.origin = origin;
  }

  /// The origin of the coordinate system (relative to the upper left corder of
  /// this render object) in which to apply the matrix.
  ///
  /// Setting an origin is equivalent to conjugating the transform matrix by a
  /// translation. This property is provided just for convenience.
  Offset get origin => _origin;
  Offset _origin;
  set origin (Offset newOrigin) {
    if (_origin == newOrigin)
      return;
    _origin = newOrigin;
    markNeedsPaint();
  }

  /// The alignment of the origin, relative to the size of the box.
  ///
  /// This is equivalent to setting an origin based on the size of the box.
  /// If it is specified at the same time as an offset, both are applied.
  FractionalOffset get alignment => _alignment;
  FractionalOffset _alignment;
  set alignment (FractionalOffset newAlignment) {
    assert(newAlignment == null || (newAlignment.dx != null && newAlignment.dy != null));
    if (_alignment == newAlignment)
      return;
    _alignment = newAlignment;
    markNeedsPaint();
  }

  /// When set to `true`, hit tests are performed based on the position of the
  /// child as it is painted. When set to `false`, hit tests are performed
  /// ignoring the transformation.
  ///
  /// applyPaintTransform(), and therefore localToGlobal() and globalToLocal(),
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  // Note the lack of a getter for transform because Matrix4 is not immutable
  Matrix4 _transform;

  /// The matrix to transform the child by during painting.
  set transform(Matrix4 newTransform) {
    assert(newTransform != null);
    if (_transform == newTransform)
      return;
    _transform = new Matrix4.copy(newTransform);
    markNeedsPaint();
  }

  /// Sets the transform to the identity matrix.
  void setIdentity() {
    _transform.setIdentity();
    markNeedsPaint();
  }

  /// Concatenates a rotation about the x axis into the transform.
  void rotateX(double radians) {
    _transform.rotateX(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the y axis into the transform.
  void rotateY(double radians) {
    _transform.rotateY(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the z axis into the transform.
  void rotateZ(double radians) {
    _transform.rotateZ(radians);
    markNeedsPaint();
  }

  /// Concatenates a translation by (x, y, z) into the transform.
  void translate(double x, [double y = 0.0, double z = 0.0]) {
    _transform.translate(x, y, z);
    markNeedsPaint();
  }

  /// Concatenates a scale into the transform.
  void scale(double x, [double y, double z]) {
    _transform.scale(x, y, z);
    markNeedsPaint();
  }

  Matrix4 get _effectiveTransform {
    if (_origin == null && _alignment == null)
      return _transform;
    Matrix4 result = new Matrix4.identity();
    if (_origin != null)
      result.translate(_origin.dx, _origin.dy);
    Offset translation;
    if (_alignment != null) {
      translation = _alignment.alongSize(size);
      result.translate(translation.dx, translation.dy);
    }
    result.multiply(_transform);
    if (_alignment != null)
      result.translate(-translation.dx, -translation.dy);
    if (_origin != null)
      result.translate(-_origin.dx, -_origin.dy);
    return result;
  }

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    if (transformHitTests) {
      Matrix4 inverse;
      try {
        inverse = new Matrix4.inverted(_effectiveTransform);
      } catch (e) {
        // We cannot invert the effective transform. That means the child
        // doesn't appear on screen and cannot be hit.
        return false;
      }
      Vector3 position3 = new Vector3(position.x, position.y, 0.0);
      Vector3 transformed3 = inverse.transform3(position3);
      position = new Point(transformed3.x, transformed3.y);
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Matrix4 transform = _effectiveTransform;
      Offset childOffset = MatrixUtils.getAsTranslation(transform);
      if (childOffset == null)
        context.pushTransform(needsCompositing, offset, transform, super.paint);
      else
        super.paint(context, offset + childOffset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform);
    super.applyPaintTransform(child, transform);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('transform matrix:');
    description.addAll(debugDescribeTransform(_transform));
    description.add('origin: $origin');
    description.add('alignment: $alignment');
    description.add('transformHitTests: $transformHitTests');
  }
}

/// Applies a translation transformation before painting its child. The
/// translation is expressed as a [FractionalOffset] relative to the
/// RenderFractionalTranslation box's size. Hit tests will only be detected
/// inside the bounds of the RenderFractionalTranslation, even if the contents
/// are offset such that they overflow.
class RenderFractionalTranslation extends RenderProxyBox {
  RenderFractionalTranslation({
    FractionalOffset translation,
    this.transformHitTests: true,
    RenderBox child
  }) : _translation = translation, super(child) {
    assert(translation == null || (translation.dx != null && translation.dy != null));
  }

  /// The translation to apply to the child, as a multiple of the size.
  FractionalOffset get translation => _translation;
  FractionalOffset _translation;
  set translation (FractionalOffset newTranslation) {
    assert(newTranslation == null || (newTranslation.dx != null && newTranslation.dy != null));
    if (_translation == newTranslation)
      return;
    _translation = newTranslation;
    markNeedsPaint();
  }

  /// When set to `true`, hit tests are performed based on the position of the
  /// child as it is painted. When set to `false`, hit tests are performed
  /// ignoring the transformation.
  ///
  /// applyPaintTransform(), and therefore localToGlobal() and globalToLocal(),
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    assert(!needsLayout);
    if (transformHitTests)
      position = new Point(position.x - translation.dx * size.width, position.y - translation.dy * size.height);
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(!needsLayout);
    if (child != null)
      super.paint(context, offset + translation.alongSize(size));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translate(translation.dx * size.width, translation.dy * size.height);
    super.applyPaintTransform(child, transform);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('translation: $translation');
    description.add('transformHitTests: $transformHitTests');
  }
}

/// The interface used by [CustomPaint] (in the widgets library) and
/// [RenderCustomPaint] (in the rendering library).
///
/// To implement a custom painter, subclass this interface to define your custom
/// paint delegate. [CustomPaint] subclasses must implement the [paint] and
/// [shouldRepaint] methods, and may optionally also implement the [hitTest]
/// method.
///
/// The [paint] method is called whenever the custom object needs to be repainted.
///
/// The [shouldRepaint] method is called when a new instance of the class
/// is provided, to check if the new instance actually represents different
/// information.
///
/// The most efficient way to trigger a repaint is to supply a repaint argument
/// to the constructor of the [CustomPainter]. The custom object will listen to
/// this animation and repaint whenever the animation ticks, avoiding both the
/// build and layout phases of the pipeline.
///
/// The [hitTest] method is called when the user interacts with the underlying
/// render object, to determine if the user hit the object or missed it.
abstract class CustomPainter {
  /// Creates a custom painter.
  ///
  /// The painter will repaint whenever the [repaint] animation ticks.
  const CustomPainter({ Animation<dynamic> repaint }) : _repaint = repaint;

  final Animation<dynamic> _repaint;

  /// Called whenever the object needs to paint. The given [Canvas] has its
  /// coordinate space configured such that the origin is at the top left of the
  /// box. The area of the box is the size of the [size] argument.
  ///
  /// Paint operations should remain inside the given area. Graphical operations
  /// outside the bounds may be silently ignored, clipped, or not clipped.
  ///
  /// Implementations should be wary of correctly pairing any calls to
  /// [Canvas.save]/[Canvas.saveLayer] and [Canvas.restore], otherwise all
  /// subsequent painting on this canvas may be affected, with potentially
  /// hilarious but confusing results.
  ///
  /// To paint text on a [Canvas], use a [TextPainter].
  ///
  /// To paint an image on a [Canvas]:
  ///
  /// 1. Obtain an [ImageResource], for example by using the [ImageCache.load]
  ///    method on the [imageCache] singleton.
  ///
  /// 2. Whenever the [ImageResource]'s underlying [ImageInfo] object changes
  ///    (see [ImageResource.addListener]), create a new instance of your custom
  ///    paint delegate, giving it the new [ImageInfo] object.
  ///
  /// 3. In your delegate's [paint] method, call the [Canvas.drawImage],
  ///    [Canvas.drawImageRect], or [Canvas.drawImageNine] methods to paint the
  ///    [ImageInfo.image] object, applying the [ImageInfo.scale] value to
  ///    obtain the correct rendering size.
  void paint(Canvas canvas, Size size);

  /// Called whenever a new instance of the custom painter delegate class is
  /// provided to the [RenderCustomPaint] object, or any time that a new
  /// [CustomPaint] object is created with a new instance of the custom painter
  /// delegate class (which amounts to the same thing, since the latter is
  /// implemented in terms of the former).
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return `true`, otherwise it should return
  /// `false`.
  ///
  /// If the method returns `false`, then the paint call might be optimized away.
  ///
  /// It's possible that the [paint] method will get called even if
  /// [shouldRepaint] returns `false` (e.g. if an ancestor or descendant needed to
  /// be repainted). It's also possible that the [paint] method will get called
  /// without [shouldRepaint] being called at all (e.g. if the box changes
  /// size).
  ///
  /// If a custom delegate has a particularly expensive paint function such that
  /// repaints should be avoided as much as possible, a [RepaintBoundary] or
  /// [RenderRepaintBoundary] (or other render object with [isRepaintBoundary]
  /// set to `true`) might be helpful.
  bool shouldRepaint(CustomPainter oldDelegate);

  /// Called whenever a hit test is being performed on an object that is using
  /// this custom paint delegate.
  ///
  /// The given point is relative to the same coordinate space as the last
  /// [paint] call.
  ///
  /// The default behavior is to consider all points to be hits for
  /// background painters, and no points to be hits for foreground painters.
  ///
  /// Return `true` if the given position corresponds to a point on the drawn
  /// image that should be considered a "hit", `false` if it corresponds to a
  /// point that should be considered outside the painted image, and null to use
  /// the default behavior.
  bool hitTest(Point position) => null;
}

/// Delegates its painting
///
/// When asked to paint, custom paint first asks painter to paint with the
/// current canvas and then paints its children. After painting its children,
/// custom paint asks foregroundPainter to paint. The coodinate system of the
/// canvas matches the coordinate system of the custom paint object. The
/// painters are expected to paint within a rectangle starting at the origin
/// and encompassing a region of the given size. If the painters paints outside
/// those bounds, there might be insufficient memory allocated to rasterize the
/// painting commands and the resulting behavior is undefined.
///
/// Because custom paint calls its painters during paint, you cannot dirty
/// layout or paint information during the callback.
class RenderCustomPaint extends RenderProxyBox {
  RenderCustomPaint({
    CustomPainter painter,
    CustomPainter foregroundPainter,
    RenderBox child
  }) : _painter = painter, _foregroundPainter = foregroundPainter, super(child);

  /// The background custom paint delegate.
  ///
  /// This painter, if non-null, is called to paint behind the children.
  CustomPainter get painter => _painter;
  CustomPainter _painter;
  /// Set a new background custom paint delegate.
  ///
  /// If the new delegate is the same as the previous one, this does nothing.
  ///
  /// If the new delegate is the same class as the previous one, then the new
  /// delegate has its [CustomPainter.shouldRepaint] called; if the result is
  /// `true`, then the delegate will be called.
  ///
  /// If the new delegate is a different class than the previous one, then the
  /// delegate will be called.
  ///
  /// If the new value is null, then there is no background custom painter.
  set painter (CustomPainter newPainter) {
    if (_painter == newPainter)
      return;
    CustomPainter oldPainter = _painter;
    _painter = newPainter;
    _didUpdatePainter(_painter, oldPainter);
  }

  /// The foreground custom paint delegate.
  ///
  /// This painter, if non-null, is called to paint in front of the children.
  CustomPainter get foregroundPainter => _foregroundPainter;
  CustomPainter _foregroundPainter;
  /// Set a new foreground custom paint delegate.
  ///
  /// If the new delegate is the same as the previous one, this does nothing.
  ///
  /// If the new delegate is the same class as the previous one, then the new
  /// delegate has its [CustomPainter.shouldRepaint] called; if the result is
  /// `true`, then the delegate will be called.
  ///
  /// If the new delegate is a different class than the previous one, then the
  /// delegate will be called.
  ///
  /// If the new value is null, then there is no foreground custom painter.
  set foregroundPainter (CustomPainter newPainter) {
    if (_foregroundPainter == newPainter)
      return;
    CustomPainter oldPainter = _foregroundPainter;
    _foregroundPainter = newPainter;
    _didUpdatePainter(_foregroundPainter, oldPainter);
  }

  void _didUpdatePainter(CustomPainter newPainter, CustomPainter oldPainter) {
    if (newPainter == null) {
      assert(oldPainter != null); // We should be called only for changes.
      markNeedsPaint();
    } else if (oldPainter == null ||
        newPainter.runtimeType != oldPainter.runtimeType ||
        newPainter.shouldRepaint(oldPainter)) {
      markNeedsPaint();
    }
    if (attached) {
      oldPainter._repaint?.removeListener(markNeedsPaint);
      newPainter._repaint?.addListener(markNeedsPaint);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter?._repaint?.addListener(markNeedsPaint);
    _foregroundPainter?._repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter?._repaint?.removeListener(markNeedsPaint);
    _foregroundPainter?._repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestChildren(HitTestResult result, { Point position }) {
    if (_foregroundPainter != null && (_foregroundPainter.hitTest(position) ?? false))
      return true;
    return super.hitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Point position) {
    return _painter != null && (_painter.hitTest(position) ?? true);
  }

  void _paintWithPainter(Canvas canvas, Offset offset, CustomPainter painter) {
    int debugPreviousCanvasSaveCount;
    canvas.save();
    assert(() { debugPreviousCanvasSaveCount = canvas.getSaveCount(); return true; });
    canvas.translate(offset.dx, offset.dy);
    painter.paint(canvas, size);
    assert(() {
      // This isn't perfect. For example, we can't catch the case of
      // someone first restoring, then setting a transform or whatnot,
      // then saving.
      // If this becomes a real problem, we could add logic to the
      // Canvas class to lock the canvas at a particular save count
      // such that restore() fails if it would take the lock count
      // below that number.
      int debugNewCanvasSaveCount = canvas.getSaveCount();
      if (debugNewCanvasSaveCount > debugPreviousCanvasSaveCount) {
        throw new FlutterError(
          'The $painter custom painter called canvas.save() or canvas.saveLayer() at least '
          '${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount} more '
          'time${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount == 1 ? '' : 's' } '
          'than it called canvas.restore().\n'
          'This leaves the canvas in an inconsistent state and will probably result in a broken display.\n'
          'You must pair each call to save()/saveLayer() with a later matching call to restore().'
        );
      }
      if (debugNewCanvasSaveCount < debugPreviousCanvasSaveCount) {
        throw new FlutterError(
          'The $painter custom painter called canvas.restore() '
          '${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount} more '
          'time${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount == 1 ? '' : 's' } '
          'than it called canvas.save() or canvas.saveLayer().\n'
          'This leaves the canvas in an inconsistent state and will result in a broken display.\n'
          'You should only call restore() if you first called save() or saveLayer().'
        );
      }
      return debugNewCanvasSaveCount == debugPreviousCanvasSaveCount;
    });
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_painter != null)
      _paintWithPainter(context.canvas, offset, _painter);
    super.paint(context, offset);
    if (_foregroundPainter != null)
      _paintWithPainter(context.canvas, offset, _foregroundPainter);
  }
}

typedef void PointerDownEventListener(PointerDownEvent event);
typedef void PointerMoveEventListener(PointerMoveEvent event);
typedef void PointerUpEventListener(PointerUpEvent event);
typedef void PointerCancelEventListener(PointerCancelEvent event);

/// Calls the callbacks in response to pointer events.
class RenderPointerListener extends RenderProxyBoxWithHitTestBehavior {
  RenderPointerListener({
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    HitTestBehavior behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(behavior: behavior, child: child);

  PointerDownEventListener onPointerDown;
  PointerMoveEventListener onPointerMove;
  PointerUpEventListener onPointerUp;
  PointerCancelEventListener onPointerCancel;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (onPointerDown != null && event is PointerDownEvent)
      return onPointerDown(event);
    if (onPointerMove != null && event is PointerMoveEvent)
      return onPointerMove(event);
    if (onPointerUp != null && event is PointerUpEvent)
      return onPointerUp(event);
    if (onPointerCancel != null && event is PointerCancelEvent)
      return onPointerCancel(event);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    List<String> listeners = <String>[];
    if (onPointerDown != null)
      listeners.add('down');
    if (onPointerMove != null)
      listeners.add('move');
    if (onPointerUp != null)
      listeners.add('up');
    if (onPointerCancel != null)
      listeners.add('cancel');
    if (listeners.isEmpty)
      listeners.add('<none>');
    description.add('listeners: ${listeners.join(", ")}');
  }
}

/// Creates a separate display list for its child.
///
/// This render object creates a separate display list for its child, which
/// can improve performance if the subtree repaints at different times than
/// the surrounding parts of the tree. Specifically, when the child does not
/// repaint but its parent does, we can re-use the display list we recorded
/// previously. Similarly, when the child repaints but the surround tree does
/// not, we can re-record its display list without re-recording the display list
/// for the surround tree.
///
/// In some cases, it is necessary to place _two_ (or more) repaint boundaries
/// to get a useful effect. Consider, for example, an e-mail application that
/// shows an unread count and a list of e-mails. Whenever a new e-mail comes in,
/// the list would update, but so would the unread count. If only one of these
/// two parts of the application was behind a repaint boundary, the entire
/// application would repaint each time. On the other hand, if both were behind
/// a repaint boundary, a new e-mail would only change those two parts of the
/// application and the rest of the application would not repaint.
///
/// To tell if a particular RenderRepaintBoundary is useful, run your
/// application in checked mode, interacting with it in typical ways, and then
/// call [debugDumpRenderTree]. Each RenderRepaintBoundary will include the
/// ratio of cases where the repaint boundary was useful vs the cases where it
/// was not. These counts can also be inspected programmatically using
/// [debugAsymmetricPaintCount] and [debugSymmetricPaintCount] respectively.
class RenderRepaintBoundary extends RenderProxyBox {
  RenderRepaintBoundary({ RenderBox child }) : super(child);

  @override
  bool get isRepaintBoundary => true;

  /// The number of times that this render object repainted at the same time as
  /// its parent. Repaint boundaries are only useful when the parent and child
  /// paint at different times. When both paint at the same time, the repaint
  /// boundary is redundant, and may be actually making performance worse.
  ///
  /// Only valid in checked mode. In release builds, always returns zero.
  ///
  /// Can be reset using [debugResetMetrics]. See [debugAsymmetricPaintCount]
  /// for the corresponding count of times where only the parent or only the
  /// child painted.
  int get debugSymmetricPaintCount => _debugSymmetricPaintCount;
  int _debugSymmetricPaintCount = 0;

  /// The number of times that either this render object repainted without the
  /// parent being painted, or the parent repainted without this object being
  /// painted. When a repaint boundary is used at a seam in the render tree
  /// where the parent tends to repaint at entirely different times than the
  /// child, it can improve performance by reducing the number of paint
  /// operations that have to be recorded each frame.
  ///
  /// Only valid in checked mode. In release builds, always returns zero.
  ///
  /// Can be reset using [debugResetMetrics]. See [debugSymmetricPaintCount] for
  /// the corresponding count of times where both the parent and the child
  /// painted together.
  int get debugAsymmetricPaintCount => _debugAsymmetricPaintCount;
  int _debugAsymmetricPaintCount = 0;

  /// Resets the [debugSymmetricPaintCount] and [debugAsymmetricPaintCount]
  /// counts to zero.
  ///
  /// Only valid in checked mode. Does nothing in release builds.
  void debugResetMetrics() {
    assert(() {
      _debugSymmetricPaintCount = 0;
      _debugAsymmetricPaintCount = 0;
      return true;
    });
  }

  @override
  void debugRegisterRepaintBoundaryPaint({ bool includedParent: true, bool includedChild: false }) {
    assert(() {
      if (includedParent && includedChild)
        _debugSymmetricPaintCount += 1;
      else
        _debugAsymmetricPaintCount += 1;
      return true;
    });
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    bool inReleaseMode = true;
    assert(() {
      inReleaseMode = false;
      if (debugSymmetricPaintCount + debugAsymmetricPaintCount == 0) {
        description.add('usefulness ratio: no metrics collected yet (never painted)');
      } else {
        double percentage = 100.0 * debugAsymmetricPaintCount / (debugSymmetricPaintCount + debugAsymmetricPaintCount);
        String diagnosis;
        if (debugSymmetricPaintCount + debugAsymmetricPaintCount < 5) {
          diagnosis = 'insufficient data to draw conclusion (less than five repaints)';
        } else if (percentage > 90.0) {
          diagnosis = 'this is an outstandingly useful repaint boundary and should definitely be kept';
        } else if (percentage > 50.0) {
          diagnosis = 'this is a useful repaint boundary and should be kept';
        } else if (percentage > 30.0) {
          diagnosis = 'this repaint boundary is probably useful, but maybe it would be more useful in tandem with adding more repaint boundaries elsewhere';
        } else if (percentage > 10.0) {
          diagnosis = 'this repaint boundary does sometimes show value, though currently not that often';
        } else if (debugAsymmetricPaintCount == 0) {
          diagnosis = 'this repaint boundary is astoundingly ineffectual and should be removed';
        } else {
          diagnosis = 'this repaint boundary is not very effective and should probably be removed';
        }
        description.add('metrics: ${percentage.toStringAsFixed(1)}% useful ($debugSymmetricPaintCount bad vs $debugAsymmetricPaintCount good)');
        description.add('diagnosis: $diagnosis');
      }
      return true;
    });
    if (inReleaseMode)
      description.add('(run in checked mode to collect repaint boundary statistics)');
  }
}

/// Is invisible during hit testing.
///
/// When [ignoring] is `true`, this render object (and its subtree) is invisible
/// to hit testing. It still consumes space during layout and paints its child
/// as usual. It just cannot be the target of located events because it returns
/// `false` from [hitTest].
///
/// When [ignoringSemantics] is `true`, the subtree will be invisible to
/// the semantics layer (and thus e.g. accessibility tools). If
/// [ignoringSemantics] is null, it uses the value of [ignoring].
class RenderIgnorePointer extends RenderProxyBox {
  RenderIgnorePointer({
    RenderBox child,
    bool ignoring: true,
    bool ignoringSemantics
  }) : _ignoring = ignoring, _ignoringSemantics = ignoringSemantics, super(child) {
    assert(_ignoring != null);
  }

  bool get ignoring => _ignoring;
  bool _ignoring;
  set ignoring(bool value) {
    assert(value != null);
    if (value == _ignoring)
      return;
    _ignoring = value;
    if (ignoringSemantics == null)
      markNeedsSemanticsUpdate();
  }

  bool get ignoringSemantics => _ignoringSemantics;
  bool _ignoringSemantics;
  set ignoringSemantics(bool value) {
    if (value == _ignoringSemantics)
      return;
    bool oldEffectiveValue = _effectiveIgnoringSemantics;
    _ignoringSemantics = value;
    if (oldEffectiveValue != _effectiveIgnoringSemantics)
      markNeedsSemanticsUpdate();
  }

  bool get _effectiveIgnoringSemantics => ignoringSemantics == null ? ignoring : ignoringSemantics;

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    return ignoring ? false : super.hitTest(result, position: position);
  }

  // TODO(ianh): figure out a way to still include labels and flags in
  // descendants, just make them non-interactive, even when
  // _effectiveIgnoringSemantics is true
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && !_effectiveIgnoringSemantics)
      visitor(child);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('ignoring: $ignoring');
    description.add('ignoringSemantics: ${ ignoringSemantics == null ? "implicitly " : "" }$_effectiveIgnoringSemantics');
  }
}

/// Holds opaque meta data in the render tree.
class RenderMetaData extends RenderProxyBoxWithHitTestBehavior {
  RenderMetaData({
    this.metaData,
    HitTestBehavior behavior: HitTestBehavior.deferToChild,
    RenderBox child
  }) : super(behavior: behavior, child: child);

  /// Opaque meta data ignored by the render tree
  dynamic metaData;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('metaData: $metaData');
  }
}

/// Listens for the specified gestures from the semantics server (e.g.
/// an accessibility tool).
class RenderSemanticsGestureHandler extends RenderProxyBox implements SemanticActionHandler {
  RenderSemanticsGestureHandler({
    RenderBox child,
    GestureTapCallback onTap,
    GestureLongPressCallback onLongPress,
    GestureDragUpdateCallback onHorizontalDragUpdate,
    GestureDragUpdateCallback onVerticalDragUpdate,
    this.scrollFactor: 0.8
  }) : _onTap = onTap,
       _onLongPress = onLongPress,
       _onHorizontalDragUpdate = onHorizontalDragUpdate,
       _onVerticalDragUpdate = onVerticalDragUpdate,
       super(child);

  GestureTapCallback get onTap => _onTap;
  GestureTapCallback _onTap;
  set onTap(GestureTapCallback value) {
    if (_onTap == value)
      return;
    bool didHaveSemantics = hasSemantics;
    bool hadHandler = _onTap != null;
    _onTap = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyChanges: hasSemantics == didHaveSemantics);
  }

  GestureLongPressCallback get onLongPress => _onLongPress;
  GestureLongPressCallback _onLongPress;
  set onLongPress(GestureLongPressCallback value) {
    if (_onLongPress == value)
      return;
    bool didHaveSemantics = hasSemantics;
    bool hadHandler = _onLongPress != null;
    _onLongPress = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyChanges: hasSemantics == didHaveSemantics);
  }

  GestureDragUpdateCallback get onHorizontalDragUpdate => _onHorizontalDragUpdate;
  GestureDragUpdateCallback _onHorizontalDragUpdate;
  set onHorizontalDragUpdate(GestureDragUpdateCallback value) {
    if (_onHorizontalDragUpdate == value)
      return;
    bool didHaveSemantics = hasSemantics;
    bool hadHandler = _onHorizontalDragUpdate != null;
    _onHorizontalDragUpdate = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyChanges: hasSemantics == didHaveSemantics);
  }

  GestureDragUpdateCallback get onVerticalDragUpdate => _onVerticalDragUpdate;
  GestureDragUpdateCallback _onVerticalDragUpdate;
  set onVerticalDragUpdate(GestureDragUpdateCallback value) {
    if (_onVerticalDragUpdate == value)
      return;
    bool didHaveSemantics = hasSemantics;
    bool hadHandler = _onVerticalDragUpdate != null;
    _onVerticalDragUpdate = value;
    if ((value != null) != hadHandler)
      markNeedsSemanticsUpdate(onlyChanges: hasSemantics == didHaveSemantics);
  }

  /// The fraction of the dimension of this render box to use when
  /// scrolling. For example, if this is 0.8 and the box is 200 pixels
  /// wide, then when a left-scroll action is received from the
  /// accessibility system, it will translate into a 160 pixel
  /// leftwards drag.
  double scrollFactor;

  @override
  bool get hasSemantics {
    return onTap != null
        || onLongPress != null
        || onHorizontalDragUpdate != null
        || onVerticalDragUpdate != null;
  }

  @override
  Iterable<SemanticAnnotator> getSemanticAnnotators() sync* {
    if (hasSemantics) {
      yield (SemanticsNode semantics) {
        semantics.canBeTapped = onTap != null;
        semantics.canBeLongPressed = onLongPress != null;
        semantics.canBeScrolledHorizontally = onHorizontalDragUpdate != null;
        semantics.canBeScrolledVertically = onVerticalDragUpdate != null;
      };
    }
  }

  @override
  void handleSemanticTap() {
    if (onTap != null)
      onTap();
  }

  @override
  void handleSemanticLongPress() {
    if (onLongPress != null)
      onLongPress();
  }

  @override
  void handleSemanticScrollLeft() {
    if (onHorizontalDragUpdate != null)
      onHorizontalDragUpdate(size.width * -scrollFactor);
  }

  @override
  void handleSemanticScrollRight() {
    if (onHorizontalDragUpdate != null)
      onHorizontalDragUpdate(size.width * scrollFactor);
  }

  @override
  void handleSemanticScrollUp() {
    if (onVerticalDragUpdate != null)
      onVerticalDragUpdate(size.height * -scrollFactor);
  }

  @override
  void handleSemanticScrollDown() {
    if (onVerticalDragUpdate != null)
      onVerticalDragUpdate(size.height * scrollFactor);
  }
}

/// Add annotations to the SemanticsNode for this subtree.
class RenderSemanticAnnotations extends RenderProxyBox {
  RenderSemanticAnnotations({
    RenderBox child,
    bool container: false,
    bool checked,
    String label
  }) : _container = container,
       _checked = checked,
       _label = label,
       super(child) {
    assert(container != null);
  }

  /// If 'container' is `true`, this RenderObject will introduce a new
  /// node in the semantics tree. Otherwise, the semantics will be
  /// merged with the semantics of any ancestors.
  ///
  /// The 'container' flag is implicitly set to `true` on the immediate
  /// semantics-providing descendants of a node where multiple
  /// children have semantics or have descendants providing semantics.
  /// In other words, the semantics of siblings are not merged. To
  /// merge the semantics of an entire subtree, including siblings,
  /// you can use a [RenderMergeSemantics].
  bool get container => _container;
  bool _container;
  set container(bool value) {
    assert(value != null);
    if (container == value)
      return;
    _container = value;
    markNeedsSemanticsUpdate();
  }

  /// If non-null, sets the "hasCheckedState" semantic to `true` and the
  /// "isChecked" semantic to the given value.
  bool get checked => _checked;
  bool _checked;
  set checked(bool value) {
    if (checked == value)
      return;
    bool hadValue = checked != null;
    _checked = value;
    markNeedsSemanticsUpdate(onlyChanges: (value != null) == hadValue);
  }

  /// If non-null, sets the "label" semantic to the given value.
  String get label => _label;
  String _label;
  set label(String value) {
    if (label == value)
      return;
    bool hadValue = label != null;
    _label = value;
    markNeedsSemanticsUpdate(onlyChanges: (value != null) == hadValue);
  }

  @override
  bool get hasSemantics => container;

  @override
  Iterable<SemanticAnnotator> getSemanticAnnotators() sync* {
    if (checked != null) {
      yield (SemanticsNode semantics) {
        semantics.hasCheckedState = true;
        semantics.isChecked = checked;
      };
    }
    if (label != null) {
      yield (SemanticsNode semantics) {
        semantics.label = label;
      };
    }
  }
}

/// Causes the semantics of all descendants to be merged into this
/// node such that the entire subtree becomes a single leaf in the
/// semantics tree.
///
/// Useful for combining the semantics of multiple render objects that
/// form part of a single conceptual widget, e.g. a checkbox, a label,
/// and the gesture detector that goes with them.
class RenderMergeSemantics extends RenderProxyBox {
  RenderMergeSemantics({ RenderBox child }) : super(child);

  @override
  Iterable<SemanticAnnotator> getSemanticAnnotators() sync* {
    yield (SemanticsNode node) { node.mergeAllDescendantsIntoThisNode = true; };
  }
}

/// Excludes this subtree from the semantic tree.
///
/// Useful e.g. for hiding text that is redundant with other text next
/// to it (e.g. text included only for the visual effect).
class RenderExcludeSemantics extends RenderProxyBox {
  RenderExcludeSemantics({ RenderBox child }) : super(child);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) { }
}
