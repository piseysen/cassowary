// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart';

import 'box.dart';
import 'object.dart';

export 'package:flutter/src/painting/box_painter.dart';
export 'package:flutter/gestures.dart' show InputEvent, PointerInputEvent;

/// A base class for render objects that resemble their children
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
    if (child != null)
      return child.getMinIntrinsicWidth(constraints);
    return super.getMinIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints);
    return super.getMaxIntrinsicWidth(constraints);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(constraints);
    return super.getMinIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
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

  void hitTestChildren(HitTestResult result, { Point position }) {
    if (child != null)
      child.hitTest(result, position: position);
    else
      super.hitTestChildren(result, position: position);
  }

  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child, offset.toPoint());
  }
}

/// A render object that imposes additional constraints on its child
///
/// A render constrained box proxies most functions in the render box protocol
/// to its child, except that when laying out its child, it tightens the
/// constraints provided by its parent by enforcing the [additionalConstraints]
/// as well.
///
/// For example, if you wanted [child] to have a minimum height, you could use
/// `const BoxConstraints(minHeight: 50.0)`` as the [additionalConstraints].
class RenderConstrainedBox extends RenderProxyBox {
  RenderConstrainedBox({
    RenderBox child,
    BoxConstraints additionalConstraints
  }) : _additionalConstraints = additionalConstraints, super(child) {
    assert(additionalConstraints != null);
  }

  /// Additional constraints to apply to [child] during layout
  BoxConstraints get additionalConstraints => _additionalConstraints;
  BoxConstraints _additionalConstraints;
  void set additionalConstraints (BoxConstraints newConstraints) {
    assert(newConstraints != null);
    if (_additionalConstraints == newConstraints)
      return;
    _additionalConstraints = newConstraints;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainWidth(0.0);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(_additionalConstraints.enforce(constraints));
    return _additionalConstraints.enforce(constraints).constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
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

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}additionalConstraints: $additionalConstraints\n';
}

/// A render object that, for both width and height, imposes a tight constraint
/// on its child that is a multiple (typically less than 1.0) of the maximum
/// constraint it received from its parent on that axis. If the factor for a
/// given axis is null, then the constraints from the parent are just passed
/// through instead.
///
/// It then tries to size itself the size of its child.
class RenderFractionallySizedBox extends RenderProxyBox {
  RenderFractionallySizedBox({
    RenderBox child,
    double widthFactor,
    double heightFactor
  }) : _widthFactor = widthFactor, _heightFactor = heightFactor, super(child) {
    assert(_widthFactor == null || _widthFactor > 0.0);
    assert(_heightFactor == null || _heightFactor > 0.0);
  }

  /// The multiple to apply to the incoming maximum width constraint to use as
  /// the tight width constraint for the child, or null to pass through the
  /// constraints given by the parent.
  double get widthFactor => _widthFactor;
  double _widthFactor;
  void set widthFactor (double value) {
    assert(value == null || value > 0.0);
    if (_widthFactor == value)
      return;
    _widthFactor = value;
    markNeedsLayout();
  }

  /// The multiple to apply to the incoming maximum height constraint to use as
  /// the tight height constraint for the child, or null to pass through the
  /// constraints given by the parent.
  double get heightFactor => _heightFactor;
  double _heightFactor;
  void set heightFactor (double value) {
    assert(value == null || value > 0.0);
    if (_heightFactor == value)
      return;
    _heightFactor = value;
    markNeedsLayout();
  }

  BoxConstraints _computeChildConstraints(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: _widthFactor == null ? constraints.minWidth : constraints.maxWidth * _widthFactor,
      maxWidth: _widthFactor == null ? constraints.maxWidth : constraints.maxWidth * _widthFactor,
      minHeight: _heightFactor == null ? constraints.minHeight : constraints.maxHeight * _heightFactor,
      maxHeight: _heightFactor == null ? constraints.maxHeight : constraints.maxHeight * _heightFactor
    );
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicWidth(_computeChildConstraints(constraints));
    return _computeChildConstraints(constraints).constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(_computeChildConstraints(constraints));
    return _computeChildConstraints(constraints).constrainWidth(0.0);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(_computeChildConstraints(constraints));
    return _computeChildConstraints(constraints).constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicHeight(_computeChildConstraints(constraints));
    return _computeChildConstraints(constraints).constrainHeight(0.0);
  }

  void performLayout() {
    if (child != null) {
      child.layout(_computeChildConstraints(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _computeChildConstraints(constraints).constrain(Size.zero);
    }
  }

  String debugDescribeSettings(String prefix) {
    return '${super.debugDescribeSettings(prefix)}' +
           '${prefix}widthFactor: ${_widthFactor ?? "pass-through"}\n' +
           '${prefix}heightFactor: ${_heightFactor ?? "pass-through"}\n';
  }
}

/// A render object that imposes different constraints on its child than it gets
/// from its parent, possibly allowing the child to overflow the parent.
///
/// A render overflow box proxies most functions in the render box protocol to
/// its child, except that when laying out its child, it passes constraints
/// based on the minWidth, maxWidth, minHeight, and maxHeight fields instead of
/// just passing the parent's constraints in. Specifically, it overrides any of
/// the equivalent fields on the constraints given by the parent with the
/// constraints given by these fields for each such field that is not null. It
/// then sizes itself based on the parent's constraints' maxWidth and maxHeight,
/// ignoring the child's dimensions.
///
/// For example, if you wanted a box to always render 50 pixels high, regardless
/// of where it was rendered, you would wrap it in a RenderOverflow with
/// minHeight and maxHeight set to 50.0. Generally speaking, to avoid confusing
/// behaviour around hit testing, a RenderOverflowBox should usually be wrapped
/// in a RenderClipRect.
///
/// The child is positioned at the top left of the box. To position a smaller
/// child inside a larger parent, use [RenderPositionedBox] and
/// [RenderConstrainedBox] rather than RenderOverflowBox.
class RenderOverflowBox extends RenderProxyBox {
  RenderOverflowBox({
    RenderBox child,
    double minWidth,
    double maxWidth,
    double minHeight,
    double maxHeight
  }) : _minWidth = minWidth, _maxWidth = maxWidth, _minHeight = minHeight, _maxHeight = maxHeight, super(child);

  /// The minimum width constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  double get minWidth => _minWidth;
  double _minWidth;
  void set minWidth (double value) {
    if (_minWidth == value)
      return;
    _minWidth = value;
    markNeedsLayout();
  }

  /// The maximum width constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  double get maxWidth => _maxWidth;
  double _maxWidth;
  void set maxWidth (double value) {
    if (_maxWidth == value)
      return;
    _maxWidth = value;
    markNeedsLayout();
  }

  /// The minimum height constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  double get minHeight => _minHeight;
  double _minHeight;
  void set minHeight (double value) {
    if (_minHeight == value)
      return;
    _minHeight = value;
    markNeedsLayout();
  }

  /// The maximum height constraint to give the child. Set this to null (the
  /// default) to use the constraint from the parent instead.
  double get maxHeight => _maxHeight;
  double _maxHeight;
  void set maxHeight (double value) {
    if (_maxHeight == value)
      return;
    _maxHeight = value;
    markNeedsLayout();
  }

  BoxConstraints childConstraints(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: _minWidth ?? constraints.minWidth,
      maxWidth: _maxWidth ?? constraints.maxWidth,
      minHeight: _minHeight ?? constraints.minHeight,
      maxHeight: _maxHeight ?? constraints.maxHeight
    );
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return constraints.constrainWidth();
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return constraints.constrainWidth();
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return constraints.constrainHeight();
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return constraints.constrainHeight();
  }

  bool get sizedByParent => true;

  void performResize() {
    size = constraints.biggest;
  }

  void performLayout() {
    if (child != null)
      child.layout(childConstraints(constraints));
  }

  String debugDescribeSettings(String prefix) {
    return '${super.debugDescribeSettings(prefix)}' +
           '${prefix}minWidth: ${minWidth ?? "use parent minWidth constraint"}\n' +
           '${prefix}maxWidth: ${maxWidth ?? "use parent maxWidth constraint"}\n' +
           '${prefix}minHeight: ${minHeight ?? "use parent minHeight constraint"}\n' +
           '${prefix}maxHeight: ${maxHeight ?? "use parent maxHeight constraint"}\n';
  }
}

/// Forces child to layout at a specific aspect ratio
///
/// The width of this render object is the largest width permited by the layout
/// constraints. The height of the render object is determined by applying the
/// given aspect ratio to the width, expressed as a ratio of width to height.
/// For example, a 16:9 width:height aspect ratio would have a value of 16.0/9.0.
///
/// For example, given an aspect ratio of 2.0 and layout constraints that
/// require the width to be between 0.0 and 100.0 and the height to be between
/// 0.0 and 100.0, we'll select a width of 100.0 (the biggest allowed) and a
/// height of 50.0 (to match the aspect ratio).
///
/// In that same situation, if the aspect ratio is 0.5, we'll also select a
/// width of 100.0 (still the biggest allowed) and we'll attempt to use a height
/// of 200.0. Unfortunately, that violates the constraints and we'll end up with
/// a height of 100.0 instead.
class RenderAspectRatio extends RenderProxyBox {
  RenderAspectRatio({
    RenderBox child,
    double aspectRatio
  }) : _aspectRatio = aspectRatio, super(child) {
    assert(_aspectRatio != null);
  }

  /// The aspect ratio to use when computing the height from the width
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

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return _applyAspectRatio(constraints).height;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return _applyAspectRatio(constraints).height;
  }

  Size _applyAspectRatio(BoxConstraints constraints) {
    double width = constraints.constrainWidth();
    double height = constraints.constrainHeight(width / _aspectRatio);
    return new Size(width, height);
  }

  bool get sizedByParent => true;

  void performResize() {
    size = _applyAspectRatio(constraints);
  }

  void performLayout() {
    if (child != null)
      child.layout(new BoxConstraints.tight(size));
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}aspectRatio: $aspectRatio\n';
}

/// Sizes its child to the child's intrinsic width
///
/// This class will size its child's width to the child's maximum intrinsic
/// width. If [stepWidth] is non-null, the child's width will be snapped to a
/// multiple of the [stepWidth]. Similarly, if [stepHeight] is non-null, the
/// child's height will be snapped to a multiple of the [stepHeight].
///
/// This class is useful, for example, when unlimited width is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable width.
///
/// Note: This class is relatively expensive. Avoid using it where possible.
class RenderIntrinsicWidth extends RenderProxyBox {

  RenderIntrinsicWidth({
    double stepWidth,
    double stepHeight,
    RenderBox child
  }) : _stepWidth = stepWidth, _stepHeight = stepHeight, super(child);

  /// If non-null, force the child's width to be a multiple of this value
  double get stepWidth => _stepWidth;
  double _stepWidth;
  void set stepWidth(double newStepWidth) {
    if (newStepWidth == _stepWidth)
      return;
    _stepWidth = newStepWidth;
    markNeedsLayout();
  }

  /// If non-null, force the child's height to be a multiple of this value
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
    return constraints.tightenWidth(_applyStep(width, _stepWidth));
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return getMaxIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMaxIntrinsicWidth(constraints);
    return constraints.constrainWidth(_applyStep(childResult, _stepWidth));
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainHeight(0.0);
    double childResult = child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(_applyStep(childResult, _stepHeight));
  }

  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = _getInnerConstraints(constraints);
      if (_stepHeight != null)
        childConstraints.tightenHeight(getMaxIntrinsicHeight(childConstraints));
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}stepWidth: $stepWidth\n${prefix}stepHeight: $stepHeight\n';

}

/// Sizes its child to the child's intrinsic height
///
/// This class will size its child's height to the child's maximum intrinsic
/// height.
///
/// This class is useful, for example, when unlimited height is available and
/// you would like a child that would otherwise attempt to expand infinitely to
/// instead size itself to a more reasonable height.
///
/// Note: This class is relatively expensive. Avoid using it where possible.
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
    return constraints.tightenHeight(height);
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMinIntrinsicWidth(_getInnerConstraints(constraints));
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    return child.getMaxIntrinsicWidth(_getInnerConstraints(constraints));
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return getMaxIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
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

/// Makes its child partially transparent
///
/// This class paints its child into an intermediate buffer and then blends the
/// child back into the scene partially transparent.
///
/// Note: This class is relatively expensive because it requires painting the
/// child into an intermediate buffer.
class RenderOpacity extends RenderProxyBox {
  RenderOpacity({ RenderBox child, double opacity })
    : this._opacity = opacity, super(child) {
    assert(opacity >= 0.0 && opacity <= 1.0);
  }

  /// The fraction to scale the child's alpha value
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
    markNeedsPaint();
  }

  int get _alpha => (_opacity * 255).round();

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      int a = _alpha;
      if (a == 0)
        return;
      if (a == 255)
        context.paintChild(child, offset.toPoint());
      else
        context.paintChildWithOpacity(child, offset.toPoint(), null, a);
    }
  }
}

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

  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChildWithShaderMask(child, offset.toPoint(), offset & size, _shaderCallback, _transferMode);
  }
}

/// Clips its child using a rectangle
///
/// Prevents its child from painting outside its bounds.
class RenderClipRect extends RenderProxyBox {
  RenderClipRect({ RenderBox child }) : super(child);

  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChildWithClipRect(child, offset.toPoint(), offset & size);
  }
}

/// Clips its child using a rounded rectangle
///
/// Creates a rounded rectangle from its layout dimensions and the given x and
/// y radius values and prevents its child from painting outside that rounded
/// rectangle.
class RenderClipRRect extends RenderProxyBox {
  RenderClipRRect({ RenderBox child, double xRadius, double yRadius })
    : _xRadius = xRadius, _yRadius = yRadius, super(child) {
    assert(_xRadius != null);
    assert(_yRadius != null);
  }

  /// The radius of the rounded corners in the horizontal direction in logical pixels
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

  /// The radius of the rounded corners in the vertical direction in logical pixels
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

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Rect rect = offset & size;
      ui.RRect rrect = new ui.RRect()..setRectXY(rect, xRadius, yRadius);
      context.paintChildWithClipRRect(child, offset.toPoint(), rect, rrect);
    }
  }
}

/// Clips its child using an oval
///
/// Inscribes an oval into its layout dimensions and prevents its child from
/// painting outside that oval.
class RenderClipOval extends RenderProxyBox {
  RenderClipOval({ RenderBox child }) : super(child);

  Rect _cachedRect;
  Path _cachedPath;

  Path _getPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = new Path()..addOval(_cachedRect);
    }
    return _cachedPath;
  }

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      Rect rect = offset & size;
      context.paintChildWithClipPath(child, offset.toPoint(), rect, _getPath(rect));
    }
  }
}

/// Where to paint a box decoration
enum BoxDecorationPosition {
  /// Paint the box decoration behind the children
  background,

  /// Paint the box decoration in front of the children
  foreground,
}

/// Paints a [BoxDecoration] either before or after its child paints
class RenderDecoratedBox extends RenderProxyBox {

  RenderDecoratedBox({
    BoxDecoration decoration,
    RenderBox child,
    BoxDecorationPosition position: BoxDecorationPosition.background
  }) : _painter = new BoxPainter(decoration),
       _position = position,
       super(child) {
    assert(decoration != null);
    assert(position != null);
  }

  /// Where to paint the box decoration
  BoxDecorationPosition get position => _position;
  BoxDecorationPosition _position;
  void set position (BoxDecorationPosition newPosition) {
    assert(newPosition != null);
    if (newPosition == _position)
      return;
    markNeedsPaint();
  }

  /// What decoration to paint
  BoxDecoration get decoration => _painter.decoration;
  void set decoration (BoxDecoration newDecoration) {
    assert(newDecoration != null);
    if (newDecoration == _painter.decoration)
      return;
    _removeBackgroundImageListenerIfNeeded();
    _painter.decoration = newDecoration;
    _addBackgroundImageListenerIfNeeded();
    markNeedsPaint();
  }

  final BoxPainter _painter;

  bool get _needsBackgroundImageListener {
    return attached &&
        _painter.decoration != null &&
        _painter.decoration.backgroundImage != null;
  }

  void _addBackgroundImageListenerIfNeeded() {
    if (_needsBackgroundImageListener)
      _painter.decoration.backgroundImage.addChangeListener(markNeedsPaint);
  }

  void _removeBackgroundImageListenerIfNeeded() {
    if (_needsBackgroundImageListener)
      _painter.decoration.backgroundImage.removeChangeListener(markNeedsPaint);
  }

  void attach() {
    super.attach();
    _addBackgroundImageListenerIfNeeded();
  }

  void detach() {
    _removeBackgroundImageListenerIfNeeded();
    super.detach();
  }

  void paint(PaintingContext context, Offset offset) {
    assert(size.width != null);
    assert(size.height != null);
    if (position == BoxDecorationPosition.background)
      _painter.paint(context.canvas, offset & size);
    super.paint(context, offset);
    if (position == BoxDecorationPosition.foreground)
      _painter.paint(context.canvas, offset & size);
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}decoration:\n${_painter.decoration.toString(prefix + "  ")}\n';
}

/// Applies a transformation before painting its child
class RenderTransform extends RenderProxyBox {
  RenderTransform({
    Matrix4 transform,
    Offset origin,
    FractionalOffset alignment,
    RenderBox child
  }) : super(child) {
    assert(transform != null);
    assert(alignment == null || (alignment.x != null && alignment.y != null));
    this.transform = transform;
    this.alignment = alignment;
    this.origin = origin;
  }

  /// The origin of the coordinate system (relative to the upper left corder of
  /// this render object) in which to apply the matrix
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
    assert(newAlignment == null || (newAlignment.x != null && newAlignment.y != null));
    if (_alignment == newAlignment)
      return;
    _alignment = newAlignment;
    markNeedsPaint();
  }

  // Note the lack of a getter for transform because Matrix4 is not immutable
  Matrix4 _transform;

  /// The matrix to transform the child by during painting
  void set transform(Matrix4 newTransform) {
    assert(newTransform != null);
    if (_transform == newTransform)
      return;
    _transform = new Matrix4.copy(newTransform);
    markNeedsPaint();
  }

  /// Sets the transform to the identity matrix
  void setIdentity() {
    _transform.setIdentity();
    markNeedsPaint();
  }

  /// Concatenates a rotation about the x axis into the transform
  void rotateX(double radians) {
    _transform.rotateX(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the y axis into the transform
  void rotateY(double radians) {
    _transform.rotateY(radians);
    markNeedsPaint();
  }

  /// Concatenates a rotation about the z axis into the transform
  void rotateZ(double radians) {
    _transform.rotateZ(radians);
    markNeedsPaint();
  }

  /// Concatenates a translation by (x, y, z) into the transform
  void translate(x, [double y = 0.0, double z = 0.0]) {
    _transform.translate(x, y, z);
    markNeedsPaint();
  }

  /// Concatenates a scale into the transform
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
    if (_alignment != null)
      result.translate(_alignment.x * size.width, _alignment.y * size.height);
    result.multiply(_transform);
    if (_alignment != null)
      result.translate(-_alignment.x * size.width, -_alignment.y * size.height);
    if (_origin != null)
      result.translate(-_origin.dx, -_origin.dy);
    return result;
  }

  bool hitTest(HitTestResult result, { Point position }) {
    Matrix4 inverse = new Matrix4.zero();
    // TODO(abarth): Check the determinant for degeneracy.
    inverse.copyInverse(_effectiveTransform);

    Vector3 position3 = new Vector3(position.x, position.y, 0.0);
    Vector3 transformed3 = inverse.transform3(position3);
    Point transformed = new Point(transformed3.x, transformed3.y);
    return super.hitTest(result, position: transformed);
  }

  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChildWithTransform(child, offset.toPoint(), _effectiveTransform);
  }

  void applyPaintTransform(Matrix4 transform) {
    super.applyPaintTransform(transform);
    transform.multiply(_effectiveTransform);
  }

  String debugDescribeSettings(String prefix) {
    List<String> result = _transform.toString().split('\n').map((String s) => '$prefix  $s\n').toList();
    result.removeLast();
    return '${super.debugDescribeSettings(prefix)}${prefix}transform matrix:\n${result.join()}\n${prefix}origin: $origin\n${prefix}alignment: $alignment\n';
  }
}

/// Called when a size changes
typedef void SizeChangedCallback(Size newSize);

/// Calls [onSizeChanged] whenever the child's layout size changes
///
/// Note: Size observer calls its callback during layout, which means you cannot
/// dirty layout information during the callback.
class RenderSizeObserver extends RenderProxyBox {
  RenderSizeObserver({
    this.onSizeChanged,
    RenderBox child
  }) : super(child) {
    assert(onSizeChanged != null);
  }

  /// The callback to call whenever the child's layout size changes
  SizeChangedCallback onSizeChanged;

  void performLayout() {
    Size oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size)
      onSizeChanged(size);
  }
}

/// Called when its time to paint into the given canvas
typedef void CustomPaintCallback(PaintingCanvas canvas, Size size);

/// Delegates its painting to [onPaint]
///
/// When asked to paint, custom paint first calls its callback with the current
/// canvas and then paints its children. The coodinate system of the canvas
/// matches the coordinate system of the custom paint object. The callback is
/// expected to paint with in a rectangle starting at the origin and
/// encompassing a region of the given size. If the callback paints outside
/// those bounds, there might be insufficient memory allocated to rasterize the
/// painting commands and the resulting behavior is undefined.
///
/// Note: Custom paint calls its callback during paint, which means you cannot
/// dirty layout or paint information during the callback.
class RenderCustomPaint extends RenderProxyBox {

  RenderCustomPaint({
    CustomPaintCallback onPaint,
    RenderBox child
  }) : super(child) {
    assert(onPaint != null);
    _onPaint = onPaint;
  }

  /// The callback to which this render object delegates its painting
  ///
  /// The callback must be non-null whenever the render object is attached to
  /// the render tree.
  CustomPaintCallback get onPaint => _onPaint;
  CustomPaintCallback _onPaint;
  void set onPaint (CustomPaintCallback newCallback) {
    assert(newCallback != null || !attached);
    if (_onPaint == newCallback)
      return;
    _onPaint = newCallback;
    markNeedsPaint();
  }

  void attach() {
    assert(_onPaint != null);
    super.attach();
  }

  void paint(PaintingContext context, Offset offset) {
    assert(_onPaint != null);
    context.canvas.translate(offset.dx, offset.dy);
    _onPaint(context.canvas, size);
    // TODO(abarth): We should translate back before calling super because in
    // the future, super.paint might switch our compositing layer.
    super.paint(context, Offset.zero);
    context.canvas.translate(-offset.dx, -offset.dy);
  }
}

typedef void PointerEventListener(PointerInputEvent e);

/// Invokes the callbacks in response to pointer events.
class RenderPointerListener extends RenderProxyBox {
  RenderPointerListener({
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    RenderBox child
  }) : super(child);

  PointerEventListener onPointerDown;
  PointerEventListener onPointerMove;
  PointerEventListener onPointerUp;
  PointerEventListener onPointerCancel;

  void handleEvent(InputEvent event, HitTestEntry entry) {
    if (onPointerDown != null && event.type == 'pointerdown')
      return onPointerDown(event);
    if (onPointerMove != null && event.type == 'pointermove')
      return onPointerMove(event);
    if (onPointerUp != null && event.type == 'pointerup')
      return onPointerUp(event);
    if (onPointerCancel != null && event.type == 'pointercancel')
      return onPointerCancel(event);
  }
}

/// Is invisible during hit testing.
///
/// When [ignoring] is true, this render object (and its subtree) is invisible
/// to hit testing. It still consumes space during layout and paints its child
/// as usual. It just cannot be the target of located events because it returns
/// false from [hitTest].
class RenderIgnorePointer extends RenderProxyBox {
  RenderIgnorePointer({ RenderBox child, this.ignoring: true }) : super(child);

  bool ignoring;

  bool hitTest(HitTestResult result, { Point position }) {
    return ignoring ? false : super.hitTest(result, position: position);
  }
}

/// Holds opaque meta data in the render tree
class RenderMetaData extends RenderProxyBox {
  RenderMetaData({ RenderBox child, this.metaData }) : super(child);

  /// Opaque meta data ignored by the render tree
  dynamic metaData;
}
