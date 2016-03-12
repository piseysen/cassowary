// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

  RenderProxyBox([RenderBox child = null]) {
    this.child = child;
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicWidth(constraints);
    return super.getMinIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints);
    return super.getMaxIntrinsicWidth(constraints);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicHeight(constraints);
    return super.getMinIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicHeight(constraints);
    return super.getMaxIntrinsicHeight(constraints);
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null)
      return child.getDistanceToActualBaseline(baseline);
    return super.computeDistanceToActualBaseline(baseline);
  }

  void performLayout() {
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  bool hitTestChildren(HitTestResult result, { Point position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

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

  bool hitTestSelf(Point position) => behavior == HitTestBehavior.opaque;

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
    assert(additionalConstraints.debugAssertIsNormalized);
  }

  /// Additional constraints to apply to [child] during layout
  BoxConstraints get additionalConstraints => _additionalConstraints;
  BoxConstraints _additionalConstraints;
  void set additionalConstraints (BoxConstraints newConstraints) {
    assert(newConstraints != null);
    assert(newConstraints.debugAssertIsNormalized);
    if (_additionalConstraints == newConstraints)
      return;
    _additionalConstraints = newConstraints;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicHeight(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicHeight(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainHeight(0.0);
  }

  void performLayout() {
    if (child != null) {
      child.layout(_additionalConstraints.enforce(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _additionalConstraints.enforce(constraints).constrain(Size.zero);
    }
  }

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

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('additionalConstraints: $additionalConstraints');
  }
}

/// Sizes itself to a fraction of the total available space.
///
/// For both its width and width height, this render object imposes a tight
/// constraint on its child that is a multiple (typically less than 1.0) of the
/// maximum constraint it received from its parent on that axis. If the factor
/// for a given axis is null, then the constraints from the parent are just
/// passed through instead.
///
/// It then tries to size itself t the size of its child.
class RenderFractionallySizedBox extends RenderProxyBox {
  RenderFractionallySizedBox({
    RenderBox child,
    double widthFactor,
    double heightFactor
  }) : _widthFactor = widthFactor, _heightFactor = heightFactor, super(child) {
    assert(_widthFactor == null || _widthFactor >= 0.0);
    assert(_heightFactor == null || _heightFactor >= 0.0);
  }

  /// If non-null, the factor of the incoming width to use.
  ///
  /// If non-null, the child is given a tight width constraint that is the max
  /// incoming width constraint multipled by this factor.  If null, the child is
  /// given the incoming width constraings.
  double get widthFactor => _widthFactor;
  double _widthFactor;
  void set widthFactor (double value) {
    assert(value == null || value >= 0.0);
    if (_widthFactor == value)
      return;
    _widthFactor = value;
    markNeedsLayout();
  }

  /// If non-null, the factor of the incoming height to use.
  ///
  /// If non-null, the child is given a tight height constraint that is the max
  /// incoming width constraint multipled by this factor.  If null, the child is
  /// given the incoming width constraings.
  double get heightFactor => _heightFactor;
  double _heightFactor;
  void set heightFactor (double value) {
    assert(value == null || value >= 0.0);
    if (_heightFactor == value)
      return;
    _heightFactor = value;
    markNeedsLayout();
  }

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    double minWidth = constraints.minWidth;
    double maxWidth = constraints.maxWidth;
    if (_widthFactor != null) {
      double width = maxWidth * _widthFactor;
      minWidth = width;
      maxWidth = width;
    }
    double minHeight = constraints.minHeight;
    double maxHeight = constraints.maxHeight;
    if (_heightFactor != null) {
      double height = maxHeight * _heightFactor;
      minHeight = height;
      maxHeight = height;
    }
    return new BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight
    );
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicWidth(_getInnerConstraints(constraints));
    return _getInnerConstraints(constraints).constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicWidth(_getInnerConstraints(constraints));
    return _getInnerConstraints(constraints).constrainWidth(0.0);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    return _getInnerConstraints(constraints).constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child != null)
      return child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    return _getInnerConstraints(constraints).constrainHeight(0.0);
  }

  void performLayout() {
    if (child != null) {
      child.layout(_getInnerConstraints(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _getInnerConstraints(constraints).constrain(Size.zero);
    }
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('widthFactor: ${_widthFactor ?? "pass-through"}');
    description.add('heightFactor: ${_heightFactor ?? "pass-through"}');
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
    assert(_aspectRatio != null);
  }

  /// The aspect ratio to attempt to use.
  ///
  /// The aspect ratio is expressed as a ratio of width to height. For example,
  /// a 16:9 width:height aspect ratio would have a value of 16.0/9.0.
  double get aspectRatio => _aspectRatio;
  double _aspectRatio;
  void set aspectRatio (double newAspectRatio) {
    assert(newAspectRatio != null);
    if (_aspectRatio == newAspectRatio)
      return;
    _aspectRatio = newAspectRatio;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return constraints.minWidth;
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return constraints.maxWidth;
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return constraints.minHeight;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return constraints.maxHeight;
  }

  Size _applyAspectRatio(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    assert(() {
      if (!constraints.hasBoundedWidth && !constraints.hasBoundedHeight) {
        throw new RenderingError(
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

  void performLayout() {
    size = _applyAspectRatio(constraints);
    if (child != null)
      child.layout(new BoxConstraints.tight(size));
  }

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
  void set stepWidth(double newStepWidth) {
    if (newStepWidth == _stepWidth)
      return;
    _stepWidth = newStepWidth;
    markNeedsLayout();
  }

  /// If non-null, force the child's height to be a multiple of this value.
  double get stepHeight => _stepHeight;
  double _stepHeight;
  void set stepHeight(double newStepHeight) {
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

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return getMaxIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMaxIntrinsicWidth(constraints);
    return constraints.constrainWidth(_applyStep(childResult, _stepWidth));
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

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

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMinIntrinsicWidth(_getInnerConstraints(constraints));
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMaxIntrinsicWidth(_getInnerConstraints(constraints));
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return getMaxIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    if (child == null)
      return constraints.constrainHeight(0.0);
    return child.getMaxIntrinsicHeight(constraints);
  }

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
/// This class is relatively expensive because it requires painting the child
/// into an intermediate buffer.
class RenderOpacity extends RenderProxyBox {
  RenderOpacity({ RenderBox child, double opacity: 1.0 })
    : _opacity = opacity, _alpha = _getAlphaFromOpacity(opacity), super(child) {
    assert(opacity >= 0.0 && opacity <= 1.0);
  }

  bool get alwaysNeedsCompositing => child != null && (_alpha != 0 && _alpha != 255);

  /// The fraction to scale the child's alpha value.
  ///
  /// An opacity of 1.0 is fully opaque. An opacity of 0.0 is fully transparent
  /// (i.e., invisible).
  double get opacity => _opacity;
  double _opacity;
  void set opacity (double newOpacity) {
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

  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && _alpha != 0)
      visitor(child);
  }

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
  void set shaderCallback (ShaderCallback newShaderCallback) {
    assert(newShaderCallback != null);
    if (_shaderCallback == newShaderCallback)
      return;
    _shaderCallback = newShaderCallback;
    markNeedsPaint();
  }

  TransferMode get transferMode => _transferMode;
  TransferMode _transferMode;
  void set transferMode (TransferMode newTransferMode) {
    assert(newTransferMode != null);
    if (_transferMode == newTransferMode)
      return;
    _transferMode = newTransferMode;
    markNeedsPaint();
  }

  bool get alwaysNeedsCompositing => child != null;

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      Rect rect = Point.origin & size;
      context.pushShaderMask(offset, _shaderCallback(rect), rect, _transferMode, super.paint);
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
  /// Returns true if the new instance will result in a different clip
  /// than the oldClipper instance.
  bool shouldRepaint(CustomClipper oldClipper);
}

abstract class _RenderCustomClip<T> extends RenderProxyBox {
  _RenderCustomClip({
    RenderBox child,
    CustomClipper<T> clipper
  }) : _clipper = clipper, super(child);

  /// If non-null, determines which clip to use on the child.
  CustomClipper<T> get clipper => _clipper;
  CustomClipper<T> _clipper;
  void set clipper (CustomClipper<T> newClipper) {
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
  T get _clip => _clipper?.getClip(size) ?? _defaultClip;

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

  Rect get _defaultClip => Point.origin & size;

  bool hitTest(HitTestResult result, { Point position }) {
    if (_clipper != null) {
      Rect clipRect = _clip;
      if (!clipRect.contains(position))
        return false;
    }
    return super.hitTest(result, position: position);
  }

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
  void set xRadius (double newXRadius) {
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
  void set yRadius (double newYRadius) {
    assert(newYRadius != null);
    if (_yRadius == newYRadius)
      return;
    _yRadius = newYRadius;
    markNeedsPaint();
  }

  // TODO(ianh): either convert this to the CustomClipper world, or
  // TODO(ianh): implement describeApproximatePaintClip for this class

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

  Rect get _defaultClip => Point.origin & size;

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

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Rect clipBounds = _clip;
      context.pushClipPath(needsCompositing, offset, clipBounds, _getClipPath(clipBounds), super.paint);
    }
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
  Decoration get decoration => _decoration;
  Decoration _decoration;
  void set decoration (Decoration newDecoration) {
    assert(newDecoration != null);
    if (newDecoration == _decoration)
      return;
    _removeListenerIfNeeded();
    _painter = null;
    _decoration = newDecoration;
    _addListenerIfNeeded();
    markNeedsPaint();
  }

  /// Where to paint the box decoration.
  DecorationPosition get position => _position;
  DecorationPosition _position;
  void set position (DecorationPosition newPosition) {
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

  void attach() {
    super.attach();
    _addListenerIfNeeded();
  }

  void detach() {
    _removeListenerIfNeeded();
    super.detach();
  }

  bool hitTestSelf(Point position) {
    return _decoration.hitTest(size, position);
  }

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
  void set origin (Offset newOrigin) {
    if (_origin == newOrigin)
      return;
    _origin = newOrigin;
    markNeedsPaint();
  }

  /// The alignment of the origin, relative to the size of the box.
  ///
  /// This is equivalent to setting an origin based on the size of the box.
  /// If it is specificed at the same time as an offset, both are applied.
  FractionalOffset get alignment => _alignment;
  FractionalOffset _alignment;
  void set alignment (FractionalOffset newAlignment) {
    assert(newAlignment == null || (newAlignment.dx != null && newAlignment.dy != null));
    if (_alignment == newAlignment)
      return;
    _alignment = newAlignment;
    markNeedsPaint();
  }

  /// When set to true, hit tests are performed based on the position of the
  /// child as it is painted. When set to false, hit tests are performed
  /// ignoring the transformation.
  ///
  /// applyPaintTransform(), and therefore localToGlobal() and globalToLocal(),
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  // Note the lack of a getter for transform because Matrix4 is not immutable
  Matrix4 _transform;

  /// The matrix to transform the child by during painting.
  void set transform(Matrix4 newTransform) {
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
  void translate(x, [double y = 0.0, double z = 0.0]) {
    _transform.translate(x, y, z);
    markNeedsPaint();
  }

  /// Concatenates a scale into the transform.
  void scale(x, [double y, double z]) {
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

  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform);
    super.applyPaintTransform(child, transform);
  }

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
  void set translation (FractionalOffset newTranslation) {
    assert(newTranslation == null || (newTranslation.dx != null && newTranslation.dy != null));
    if (_translation == newTranslation)
      return;
    _translation = newTranslation;
    markNeedsPaint();
  }

  /// When set to true, hit tests are performed based on the position of the
  /// child as it is painted. When set to false, hit tests are performed
  /// ignoring the transformation.
  ///
  /// applyPaintTransform(), and therefore localToGlobal() and globalToLocal(),
  /// always honor the transformation, regardless of the value of this property.
  bool transformHitTests;

  bool hitTest(HitTestResult result, { Point position }) {
    assert(!needsLayout);
    if (transformHitTests)
      position = new Point(position.x - translation.dx * size.width, position.y - translation.dy * size.height);
    return super.hitTest(result, position: position);
  }

  void paint(PaintingContext context, Offset offset) {
    assert(!needsLayout);
    if (child != null)
      super.paint(context, offset + translation.alongSize(size));
  }

  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translate(translation.dx * size.width, translation.dy * size.height);
    super.applyPaintTransform(child, transform);
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('translation: $translation');
    description.add('transformHitTests: $transformHitTests');
  }
}

abstract class CustomPainter {
  const CustomPainter();

  void paint(Canvas canvas, Size size);
  bool shouldRepaint(CustomPainter oldDelegate);
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

  CustomPainter get painter => _painter;
  CustomPainter _painter;
  void set painter (CustomPainter newPainter) {
    if (_painter == newPainter)
      return;
    CustomPainter oldPainter = _painter;
    _painter = newPainter;
    _checkForRepaint(_painter, oldPainter);
  }

  CustomPainter get foregroundPainter => _foregroundPainter;
  CustomPainter _foregroundPainter;
  void set foregroundPainter (CustomPainter newPainter) {
    if (_foregroundPainter == newPainter)
      return;
    CustomPainter oldPainter = _foregroundPainter;
    _foregroundPainter = newPainter;
    _checkForRepaint(_foregroundPainter, oldPainter);
  }

  void _checkForRepaint(CustomPainter newPainter, CustomPainter oldPainter) {
    if (newPainter == null) {
      assert(oldPainter != null); // We should be called only for changes.
      markNeedsPaint();
    } else if (oldPainter == null ||
        newPainter.runtimeType != oldPainter.runtimeType ||
        newPainter.shouldRepaint(oldPainter)) {
      markNeedsPaint();
    }
  }

  bool hitTestChildren(HitTestResult result, { Point position }) {
    if (_foregroundPainter != null && (_foregroundPainter.hitTest(position) ?? false))
      return true;
    return super.hitTestChildren(result, position: position);
  }

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
        throw new RenderingError(
          'The $painter custom painter called canvas.save() or canvas.saveLayer() at least '
          '${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount} more '
          'time${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount == 1 ? '' : 's' } '
          'than it called canvas.restore().\n'
          'This leaves the canvas in an inconsistent state and will probably result in a broken display.\n'
          'You must pair each call to save()/saveLayer() with a later matching call to restore().'
        );
      }
      if (debugNewCanvasSaveCount < debugPreviousCanvasSaveCount) {
        throw new RenderingError(
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

/// Invokes the callbacks in response to pointer events.
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
class RenderRepaintBoundary extends RenderProxyBox {
  RenderRepaintBoundary({ RenderBox child }) : super(child);
  bool get isRepaintBoundary => true;
}

/// Is invisible during hit testing.
///
/// When [ignoring] is true, this render object (and its subtree) is invisible
/// to hit testing. It still consumes space during layout and paints its child
/// as usual. It just cannot be the target of located events because it returns
/// false from [hitTest].
///
/// When [ignoringSemantics] is true, the subtree will be invisible to
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
  void set ignoring(bool value) {
    assert(value != null);
    if (value == _ignoring)
      return;
    _ignoring = value;
    if (ignoringSemantics == null)
      markNeedsSemanticsUpdate();
  }

  bool get ignoringSemantics => _ignoringSemantics;
  bool _ignoringSemantics;
  void set ignoringSemantics(bool value) {
    if (value == _ignoringSemantics)
      return;
    bool oldEffectiveValue = _effectiveIgnoringSemantics;
    _ignoringSemantics = value;
    if (oldEffectiveValue != _effectiveIgnoringSemantics)
      markNeedsSemanticsUpdate();
  }

  bool get _effectiveIgnoringSemantics => ignoringSemantics == null ? ignoring : ignoringSemantics;

  bool hitTest(HitTestResult result, { Point position }) {
    return ignoring ? false : super.hitTest(result, position: position);
  }

  // TODO(ianh): figure out a way to still include labels and flags in
  // descendants, just make them non-interactive, even when
  // _effectiveIgnoringSemantics is true
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && !_effectiveIgnoringSemantics)
      visitor(child);
  }

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
  void set onTap(GestureTapCallback value) {
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
  void set onLongPress(GestureLongPressCallback value) {
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
  void set onHorizontalDragUpdate(GestureDragUpdateCallback value) {
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
  void set onVerticalDragUpdate(GestureDragUpdateCallback value) {
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

  bool get hasSemantics {
    return onTap != null
        || onLongPress != null
        || onHorizontalDragUpdate != null
        || onVerticalDragUpdate != null;
  }

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

  void handleSemanticTap() {
    if (onTap != null)
      onTap();
  }

  void handleSemanticLongPress() {
    if (onLongPress != null)
      onLongPress();
  }

  void handleSemanticScrollLeft() {
    if (onHorizontalDragUpdate != null)
      onHorizontalDragUpdate(size.width * -scrollFactor);
  }

  void handleSemanticScrollRight() {
    if (onHorizontalDragUpdate != null)
      onHorizontalDragUpdate(size.width * scrollFactor);
  }

  void handleSemanticScrollUp() {
    if (onVerticalDragUpdate != null)
      onVerticalDragUpdate(size.height * -scrollFactor);
  }

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

  /// If 'container' is true, this RenderObject will introduce a new
  /// node in the semantics tree. Otherwise, the semantics will be
  /// merged with the semantics of any ancestors.
  ///
  /// The 'container' flag is implicitly set to true on the immediate
  /// semantics-providing descendants of a node where multiple
  /// children have semantics or have descendants providing semantics.
  /// In other words, the semantics of siblings are not merged. To
  /// merge the semantics of an entire subtree, including siblings,
  /// you can use a [RenderMergeSemantics].
  bool get container => _container;
  bool _container;
  void set container(bool value) {
    assert(value != null);
    if (container == value)
      return;
    _container = value;
    markNeedsSemanticsUpdate();
  }

  /// If non-null, sets the "hasCheckedState" semantic to true and the
  /// "isChecked" semantic to the given value.
  bool get checked => _checked;
  bool _checked;
  void set checked(bool value) {
    if (checked == value)
      return;
    bool hadValue = checked != null;
    _checked = value;
    markNeedsSemanticsUpdate(onlyChanges: (value != null) == hadValue);
  }

  /// If non-null, sets the "label" semantic to the given value.
  String get label => _label;
  String _label;
  void set label(String value) {
    if (label == value)
      return;
    bool hadValue = label != null;
    _label = value;
    markNeedsSemanticsUpdate(onlyChanges: (value != null) == hadValue);
  }

  bool get hasSemantics => container;

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
  void visitChildrenForSemantics(RenderObjectVisitor visitor) { }
}
