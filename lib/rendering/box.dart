// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:sky' as sky;

import 'package:sky/base/debug.dart';
import 'package:sky/painting/box_painter.dart';
import 'package:sky/painting/text_style.dart';
import 'package:sky/rendering/object.dart';
import 'package:vector_math/vector_math.dart';

export 'package:sky/painting/box_painter.dart';
export 'package:sky/painting/text_style.dart' show TextBaseline;

// GENERIC BOX RENDERING
// Anything that has a concept of x, y, width, height is going to derive from this

// This class should only be used in debug builds
class _DebugSize extends Size {
  _DebugSize(Size source, this._owner, this._canBeUsedByParent): super.copy(source);
  final RenderBox _owner;
  final bool _canBeUsedByParent;
}

class EdgeDims {
  // used for e.g. padding
  const EdgeDims(this.top, this.right, this.bottom, this.left);
  const EdgeDims.all(double value)
      : top = value, right = value, bottom = value, left = value;
  const EdgeDims.only({ this.top: 0.0,
                        this.right: 0.0,
                        this.bottom: 0.0,
                        this.left: 0.0 });
  const EdgeDims.symmetric({ double vertical: 0.0,
                             double horizontal: 0.0 })
    : top = vertical, left = horizontal, bottom = vertical, right = horizontal;

  final double top;
  final double right;
  final double bottom;
  final double left;

  bool operator ==(other) {
    if (identical(this, other))
      return true;
    return other is EdgeDims
        && top == other.top
        && right == other.right
        && bottom == other.bottom
        && left == other.left;
  }

  EdgeDims operator+(EdgeDims other) {
    return new EdgeDims(top + other.top,
                        right + other.right,
                        bottom + other.bottom,
                        left + other.left);
  }

  EdgeDims operator-(EdgeDims other) {
    return new EdgeDims(top - other.top,
                        right - other.right,
                        bottom - other.bottom,
                        left - other.left);
  }

  static const EdgeDims zero = const EdgeDims(0.0, 0.0, 0.0, 0.0);

  int get hashCode {
    int value = 373;
    value = 37 * value + top.hashCode;
    value = 37 * value + left.hashCode;
    value = 37 * value + bottom.hashCode;
    value = 37 * value + right.hashCode;
    return value;
  }
  String toString() => "EdgeDims($top, $right, $bottom, $left)";
}

class BoxConstraints extends Constraints {
  const BoxConstraints({
    this.minWidth: 0.0,
    this.maxWidth: double.INFINITY,
    this.minHeight: 0.0,
    this.maxHeight: double.INFINITY
  });

  BoxConstraints.tight(Size size)
    : minWidth = size.width,
      maxWidth = size.width,
      minHeight = size.height,
      maxHeight = size.height;

  const BoxConstraints.tightFor({
    double width,
    double height
  }): minWidth = width != null ? width : 0.0,
      maxWidth = width != null ? width : double.INFINITY,
      minHeight = height != null ? height : 0.0,
      maxHeight = height != null ? height : double.INFINITY;

  BoxConstraints.loose(Size size)
    : minWidth = 0.0,
      maxWidth = size.width,
      minHeight = 0.0,
      maxHeight = size.height;

  const BoxConstraints.expandWidth({
    this.maxHeight: double.INFINITY
  }): minWidth = double.INFINITY,
      maxWidth = double.INFINITY,
      minHeight = 0.0;

  const BoxConstraints.expandHeight({
    this.maxWidth: double.INFINITY
  }): minWidth = 0.0,
      minHeight = double.INFINITY,
      maxHeight = double.INFINITY;

  static const BoxConstraints expand = const BoxConstraints(
    minWidth: double.INFINITY,
    maxWidth: double.INFINITY,
    minHeight: double.INFINITY,
    maxHeight: double.INFINITY
  );

  BoxConstraints deflate(EdgeDims edges) {
    assert(edges != null);
    double horizontal = edges.left + edges.right;
    double vertical = edges.top + edges.bottom;
    return new BoxConstraints(
      minWidth: math.max(0.0, minWidth - horizontal),
      maxWidth: maxWidth - horizontal,
      minHeight: math.max(0.0, minHeight - vertical),
      maxHeight: maxHeight - vertical
    );
  }

  BoxConstraints loosen() {
    return new BoxConstraints(
      minWidth: 0.0,
      maxWidth: maxWidth,
      minHeight: 0.0,
      maxHeight: maxHeight
    );
  }

  BoxConstraints apply(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: clamp(min: constraints.minWidth, max: constraints.maxWidth, value: minWidth),
      maxWidth: clamp(min: constraints.minWidth, max: constraints.maxWidth, value: maxWidth),
      minHeight: clamp(min: constraints.minHeight, max: constraints.maxHeight, value: minHeight),
      maxHeight: clamp(min: constraints.minHeight, max: constraints.maxHeight, value: maxHeight)
    );
  }

  BoxConstraints applyWidth(double width) {
    return new BoxConstraints(minWidth: math.max(math.min(maxWidth, width), minWidth),
                              maxWidth: math.max(math.min(maxWidth, width), minWidth),
                              minHeight: minHeight,
                              maxHeight: maxHeight);
  }

  BoxConstraints applyMinWidth(double newMinWidth) {
    return new BoxConstraints(minWidth: math.max(minWidth, newMinWidth),
                              maxWidth: math.max(maxWidth, newMinWidth),
                              minHeight: minHeight,
                              maxHeight: maxHeight);
  }

  BoxConstraints applyMaxWidth(double newMaxWidth) {
    return new BoxConstraints(minWidth: minWidth,
                              maxWidth: math.min(maxWidth, newMaxWidth),
                              minHeight: minHeight,
                              maxHeight: maxHeight);
  }

  BoxConstraints applyHeight(double height) {
    return new BoxConstraints(minWidth: minWidth,
                              maxWidth: maxWidth,
                              minHeight: math.max(math.min(maxHeight, height), minHeight),
                              maxHeight: math.max(math.min(maxHeight, height), minHeight));
  }

  BoxConstraints applyMinHeight(double newMinHeight) {
    return new BoxConstraints(minWidth: minWidth,
                              maxWidth: maxWidth,
                              minHeight: math.max(minHeight, newMinHeight),
                              maxHeight: math.max(maxHeight, newMinHeight));
  }

  BoxConstraints applyMaxHeight(double newMaxHeight) {
    return new BoxConstraints(minWidth: minWidth,
                              maxWidth: maxWidth,
                              minHeight: minHeight,
                              maxHeight: math.min(maxHeight, newMaxHeight));
  }

  BoxConstraints widthConstraints() => new BoxConstraints(minWidth: minWidth, maxWidth: maxWidth);

  BoxConstraints heightConstraints() => new BoxConstraints(minHeight: minHeight, maxHeight: maxHeight);

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;

  double constrainWidth([double width = double.INFINITY]) {
    return clamp(min: minWidth, max: maxWidth, value: width);
  }

  double constrainHeight([double height = double.INFINITY]) {
    return clamp(min: minHeight, max: maxHeight, value: height);
  }

  Size constrain(Size size) {
    Size result = new Size(constrainWidth(size.width), constrainHeight(size.height));
    if (size is _DebugSize)
      result = new _DebugSize(result, size._owner, size._canBeUsedByParent);
    return result;
  }
  Size get biggest => new Size(constrainWidth(), constrainHeight());
  Size get smallest => new Size(constrainWidth(0.0), constrainHeight(0.0));

  bool get isInfinite => maxWidth >= double.INFINITY && maxHeight >= double.INFINITY;

  bool get hasTightWidth => minWidth >= maxWidth;
  bool get hasTightHeight => minHeight >= maxHeight;
  bool get isTight => hasTightWidth && hasTightHeight;

  bool contains(Size size) {
    return (minWidth <= size.width) && (size.width <= math.max(minWidth, maxWidth)) &&
           (minHeight <= size.height) && (size.height <= math.max(minHeight, maxHeight));
  }

  bool operator ==(other) {
    if (identical(this, other))
      return true;
    return other is BoxConstraints &&
           minWidth == other.minWidth &&
           maxWidth == other.maxWidth &&
           minHeight == other.minHeight &&
           maxHeight == other.maxHeight;
  }
  int get hashCode {
    int value = 373;
    value = 37 * value + minWidth.hashCode;
    value = 37 * value + maxWidth.hashCode;
    value = 37 * value + minHeight.hashCode;
    value = 37 * value + maxHeight.hashCode;
    return value;
  }

  String toString() => "BoxConstraints($minWidth<=w<$maxWidth, $minHeight<=h<$maxHeight)";
}

class BoxHitTestEntry extends HitTestEntry {
  const BoxHitTestEntry(HitTestTarget target, this.localPosition) : super(target);
  final Point localPosition;
}

class BoxParentData extends ParentData {
  Point _position = Point.origin;
  Point get position => _position;
  void set position(Point value) {
    assert(RenderObject.debugDoingLayout);
    _position = value;
  }
  String toString() => 'position=$position';
}

abstract class RenderBox extends RenderObject {

  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData)
      child.parentData = new BoxParentData();
  }

  // getMinIntrinsicWidth() should return the minimum width that this box could
  // be without failing to render its contents within itself.
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return constraints.constrainWidth(0.0);
  }

  // getMaxIntrinsicWidth() should return the smallest width beyond which
  // increasing the width never decreases the height.
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return constraints.constrainWidth(0.0);
  }

  // getMinIntrinsicHeight() should return the minimum height that this box could
  // be without failing to render its contents within itself.
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return constraints.constrainHeight(0.0);
  }

  // getMaxIntrinsicHeight should return the smallest height beyond which
  // increasing the height never decreases the width.
  // If the layout algorithm used is width-in-height-out, i.e. the height
  // depends on the width and not vice versa, then this will return the same
  // as getMinIntrinsicHeight().
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return constraints.constrainHeight(0.0);
  }

  Map<TextBaseline, double> _cachedBaselines;
  bool _ancestorUsesBaseline = false;
  static bool _debugDoingBaseline = false;
  static bool _debugSetDoingBaseline(bool value) {
    _debugDoingBaseline = value;
    return true;
  }
  // getDistanceToBaseline() returns the distance from the
  // y-coordinate of the position of the box to the y-coordinate of
  // the first given baseline in the box's contents. This is used by
  // certain layout models to align adjacent boxes on a common
  // baseline, regardless of padding, font size differences, etc. If
  // there is no baseline, and the 'onlyReal' argument was not set to
  // true, then it returns the distance from the y-coordinate of the
  // position of the box to the y-coordinate of the bottom of the box,
  // i.e., the height of the box. Only call this after layout has been
  // performed. You are only allowed to call this from the parent of
  // this node during that parent's performLayout() or paint().
  double getDistanceToBaseline(TextBaseline baseline, { bool onlyReal: false }) {
    assert(!needsLayout);
    assert(!_debugDoingBaseline);
    final parent = this.parent; // TODO(ianh): Remove this once the analyzer is cleverer
    assert(parent is RenderObject);
    assert(() {
      if (RenderObject.debugDoingLayout)
        return (RenderObject.debugActiveLayout == parent) && parent.debugDoingThisLayout;
      if (RenderObject.debugDoingPaint)
        return ((RenderObject.debugActivePaint == parent) && parent.debugDoingThisPaint) ||
               ((RenderObject.debugActivePaint == this) && debugDoingThisPaint);
      return false;
    });
    assert(_debugSetDoingBaseline(true));
    double result = getDistanceToActualBaseline(baseline);
    assert(_debugSetDoingBaseline(false));
    assert(parent == this.parent); // TODO(ianh): Remove this once the analyzer is cleverer
    if (result == null && !onlyReal)
      return size.height;
    return result;
  }
  // getDistanceToActualBaseline() must only be called from
  // getDistanceToBaseline() and computeDistanceToActualBaseline(). Do
  // not call it directly from outside those two methods. It just
  // calls computeDistanceToActualBaseline() and caches the result.
  double getDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugDoingBaseline);
    _ancestorUsesBaseline = true;
    if (_cachedBaselines == null)
      _cachedBaselines = new Map<TextBaseline, double>();
    _cachedBaselines.putIfAbsent(baseline, () => computeDistanceToActualBaseline(baseline));
    return _cachedBaselines[baseline];
  }
  // computeDistanceToActualBaseline() should return the distance from
  // the y-coordinate of the position of the box to the y-coordinate
  // of the first given baseline in the box's contents, if any, or
  // null otherwise. This is the method that you should override in
  // subclasses. This method (computeDistanceToActualBaseline())
  // should not be called directly. Use getDistanceToBaseline() if you
  // need to know the baseline of a child from performLayout(). If you
  // need the baseline during paint, cache it during performLayout().
  // Use getDistanceToActualBaseline() if you are implementing
  // computeDistanceToActualBaseline() and need to defer to a child.
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugDoingBaseline);
    return null;
  }

  BoxConstraints get constraints => super.constraints;
  bool debugDoesMeetConstraints() {
    assert(constraints != null);
    assert(_size != null);
    assert(!_size.isInfinite);
    bool result = constraints.contains(_size);
    if (!result)
      print("${this.runtimeType} does not meet its constraints. Constraints: $constraints, size: $_size");
    return result;
  }

  void markNeedsLayout() {
    if (_cachedBaselines != null && _cachedBaselines.isNotEmpty) {
      // if we have cached data, then someone must have used our data
      assert(_ancestorUsesBaseline);
      final parent = this.parent; // TODO(ianh): Remove this once the analyzer is cleverer
      assert(parent is RenderObject);
      parent.markNeedsLayout();
      assert(parent == this.parent); // TODO(ianh): Remove this once the analyzer is cleverer
      // Now that they're dirty, we can forget that they used the
      // baseline. If they use it again, then we'll set the bit
      // again, and if we get dirty again, we'll notify them again.
      _ancestorUsesBaseline = false;
      _cachedBaselines.clear();
    } else {
      // if we've never cached any data, then nobody can have used it
      assert(!_ancestorUsesBaseline);
    }
    super.markNeedsLayout();
  }
  void performResize() {
    // default behaviour for subclasses that have sizedByParent = true
    size = constraints.constrain(Size.zero);
    assert(!size.isInfinite);
  }
  void performLayout() {
    // descendants have to either override performLayout() to set both
    // width and height and lay out children, or, set sizedByParent to
    // true so that performResize()'s logic above does its thing.
    assert(sizedByParent);
  }

  bool hitTest(HitTestResult result, { Point position }) {
    hitTestChildren(result, position: position);
    result.add(new BoxHitTestEntry(this, position));
    return true;
  }
  void hitTestChildren(HitTestResult result, { Point position }) { }

  // TODO(ianh): move size up to before constraints
  // TODO(ianh): In non-debug builds, this should all just be:
  // Size size = Size.zero;
  // In debug builds, however:
  Size _size = Size.zero;
  Size get size {
    if (_size is _DebugSize) {
      final _DebugSize _size = this._size; // TODO(ianh): Remove this once the analyzer is cleverer
      assert(_size._owner == this);
      if (RenderObject.debugActiveLayout != null) {
        // we are always allowed to access our own size (for print debugging and asserts if nothing else)
        // other than us, the only object that's allowed to read our size is our parent, if they're said they will
        // if you hit this assert trying to access a child's size, pass parentUsesSize: true in layout()
        assert(debugDoingThisResize || debugDoingThisLayout ||
               (RenderObject.debugActiveLayout == parent && _size._canBeUsedByParent));
      }
      assert(_size == this._size); // TODO(ianh): Remove this once the analyzer is cleverer
    }
    return _size;
  }
  void set size(Size value) {
    assert((sizedByParent && debugDoingThisResize) ||
           (!sizedByParent && debugDoingThisLayout));
    if (value is _DebugSize) {
      assert(value._canBeUsedByParent);
      assert(value._owner.parent == this);
    }
    _size = inDebugBuild ? new _DebugSize(value, this, debugCanParentUseSize) : value;
  }

  void applyPaintTransform(Matrix4 transform) {
    if (parentData is BoxParentData) {
      Point position = (parentData as BoxParentData).position;
      transform.translate(position.x, position.y);
    }
  }

  static Point _transformPoint(Matrix4 transform, Point point) {
    Vector3 position3 = new Vector3(point.x, point.y, 0.0);
    Vector3 transformed3 = transform.transform3(position3);
    return new Point(transformed3.x, transformed3.y);
  }

  Point globalToLocal(Point point) {
    assert(attached);
    Matrix4 transform = new Matrix4.identity();
    RenderObject renderer = this;
    while(renderer != null) {
      renderer.applyPaintTransform(transform);
      renderer = renderer.parent;
    }
    /* double det = */ transform.invert();
    // TODO(abarth): Check the determinant for degeneracy.
    return _transformPoint(transform, point);
  }

  Point localToGlobal(Point point) {
    List <RenderObject> renderers = <RenderObject>[];
    for (RenderObject renderer = this; renderer != null; renderer = renderer.parent)
      renderers.add(renderer);
    Matrix4 transform = new Matrix4.identity();
    for (RenderObject renderer in renderers.reversed)
      renderer.applyPaintTransform(transform);
    return _transformPoint(transform, point);
  }

  Rect get paintBounds => Point.origin & size;
  void debugPaint(PaintingCanvas canvas, Offset offset) {
    if (debugPaintSizeEnabled)
      debugPaintSize(canvas, offset);
    if (debugPaintBaselinesEnabled)
      debugPaintBaselines(canvas, offset);
  }
  void debugPaintSize(PaintingCanvas canvas, Offset offset) {
    Paint paint = new Paint();
    paint.setStyle(sky.PaintingStyle.stroke);
    paint.strokeWidth = 1.0;
    paint.color = debugPaintSizeColor;
    canvas.drawRect(offset & size, paint);
  }
  void debugPaintBaselines(PaintingCanvas canvas, Offset offset) {
    Paint paint = new Paint();
    paint.setStyle(sky.PaintingStyle.stroke);
    paint.strokeWidth = 0.25;
    Path path;
    // ideographic baseline
    double baselineI = getDistanceToBaseline(TextBaseline.ideographic, onlyReal: true);
    if (baselineI != null) {
      paint.color = debugPaintIdeographicBaselineColor;
      path = new Path();
      path.moveTo(offset.dx, offset.dy + baselineI);
      path.lineTo(offset.dx + size.width, offset.dy + baselineI);
      canvas.drawPath(path, paint);
    }
    // alphabetic baseline
    double baselineA = getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    if (baselineA != null) {
      paint.color = debugPaintAlphabeticBaselineColor;
      path = new Path();
      path.moveTo(offset.dx, offset.dy + baselineA);
      path.lineTo(offset.dx + size.width, offset.dy + baselineA);
      canvas.drawPath(path, paint);
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}size: ${size}\n';
}

class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {

  // ProxyBox assumes the child will be at 0,0 and will have the same size

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

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null)
      canvas.paintChild(child, offset.toPoint());
  }
}

class RenderConstrainedBox extends RenderProxyBox {
  RenderConstrainedBox({
    RenderBox child,
    BoxConstraints additionalConstraints
  }) : super(child), _additionalConstraints = additionalConstraints {
    assert(additionalConstraints != null);
  }

  BoxConstraints _additionalConstraints;
  BoxConstraints get additionalConstraints => _additionalConstraints;
  void set additionalConstraints (BoxConstraints value) {
    assert(value != null);
    if (_additionalConstraints == value)
      return;
    _additionalConstraints = value;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicWidth(_additionalConstraints.apply(constraints));
    return _additionalConstraints.apply(constraints).constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(_additionalConstraints.apply(constraints));
    return _additionalConstraints.apply(constraints).constrainWidth(0.0);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(_additionalConstraints.apply(constraints));
    return _additionalConstraints.apply(constraints).constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicHeight(_additionalConstraints.apply(constraints));
    return _additionalConstraints.apply(constraints).constrainHeight(0.0);
  }

  void performLayout() {
    if (child != null) {
      child.layout(_additionalConstraints.apply(constraints), parentUsesSize: true);
      size = child.size;
    } else {
      size = _additionalConstraints.apply(constraints).constrain(Size.zero);
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}additionalConstraints: ${additionalConstraints}\n';
}

class RenderAspectRatio extends RenderProxyBox {
  RenderAspectRatio({
    RenderBox child,
    double aspectRatio
  }) : super(child), _aspectRatio = aspectRatio {
    assert(_aspectRatio != null);
  }

  double _aspectRatio;
  double get aspectRatio => _aspectRatio;
  void set aspectRatio (double value) {
    assert(value != null);
    if (_aspectRatio == value)
      return;
    _aspectRatio = value;
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

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}aspectRatio: ${aspectRatio}\n';
}

class RenderShrinkWrapWidth extends RenderProxyBox {

  // This class will attempt to size its child to the child's maximum
  // intrinsic width, snapped to a multiple of the stepWidth, if one
  // is provided, and given the provided constraints; and will then
  // adopt the child's resulting dimensions.

  // Note: laying out this class is relatively expensive. Avoid using
  // it where possible.

  RenderShrinkWrapWidth({
    double stepWidth,
    double stepHeight,
    RenderBox child
  }) : _stepWidth = stepWidth, _stepHeight = stepHeight, super(child);

  double _stepWidth;
  double get stepWidth => _stepWidth;
  void set stepWidth(double value) {
    if (value == _stepWidth)
      return;
    _stepWidth = value;
    markNeedsLayout();
  }

  double _stepHeight;
  double get stepHeight => _stepHeight;
  void set stepHeight(double value) {
    if (value == _stepHeight)
      return;
    _stepHeight = value;
    markNeedsLayout();
  }

  static double applyStep(double input, double step) {
    if (step == null)
      return input;
    return (input / step).ceil() * step;
  }

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    if (constraints.hasTightWidth)
      return constraints;
    double width = child.getMaxIntrinsicWidth(constraints);
    assert(width == constraints.constrainWidth(width));
    return constraints.applyWidth(applyStep(width, _stepWidth));
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return getMaxIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMaxIntrinsicWidth(constraints);
    return constraints.constrainWidth(applyStep(childResult, _stepWidth));
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(applyStep(childResult, _stepHeight));
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return constraints.constrainWidth(0.0);
    double childResult = child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    return constraints.constrainHeight(applyStep(childResult, _stepHeight));
  }

  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = _getInnerConstraints(constraints);
      if (_stepHeight != null)
        childConstraints.applyHeight(getMaxIntrinsicHeight(childConstraints));
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}stepWidth: ${stepWidth}\n${prefix}stepHeight: ${stepHeight}\n';

}

class RenderOpacity extends RenderProxyBox {
  RenderOpacity({ RenderBox child, double opacity })
    : this._opacity = opacity, super(child) {
    assert(opacity >= 0.0 && opacity <= 1.0);
  }

  double _opacity;
  double get opacity => _opacity;
  void set opacity (double value) {
    assert(value != null);
    assert(value >= 0.0 && value <= 1.0);
    if (_opacity == value)
      return;
    _opacity = value;
    _cachedPaint = null;
    markNeedsPaint();
  }

  int get _alpha => (_opacity * 255).round();

  Paint _cachedPaint;
  Paint get _paint {
    if (_cachedPaint == null) {
      _cachedPaint =  new Paint()
        ..color = new Color.fromARGB(_alpha, 0, 0, 0)
        ..setTransferMode(sky.TransferMode.srcOver)
        ..isAntiAlias = false;
    }
    return _cachedPaint;
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      int a = _alpha;

      if (a == 0)
        return;

      if (a == 255) {
        canvas.paintChild(child, offset.toPoint());
        return;
      }

      canvas.saveLayer(null, _paint);
      canvas.paintChild(child, offset.toPoint());
      canvas.restore();
    }
  }
}

class RenderColorFilter extends RenderProxyBox {
  RenderColorFilter({ RenderBox child, Color color, sky.TransferMode transferMode })
    : _color = color, _transferMode = transferMode, super(child) {
  }

  Color _color;
  Color get color => _color;
  void set color (Color value) {
    assert(value != null);
    if (_color == value)
      return;
    _color = value;
    _cachedPaint = null;
    markNeedsPaint();
  }

  sky.TransferMode _transferMode;
  sky.TransferMode get transferMode => _transferMode;
  void set transferMode (sky.TransferMode value) {
    assert(value != null);
    if (_transferMode == value)
      return;
    _transferMode = value;
    _cachedPaint = null;
    markNeedsPaint();
  }

  Paint _cachedPaint;
  Paint get _paint {
    if (_cachedPaint == null) {
      _cachedPaint = new Paint()
        ..setColorFilter(new sky.ColorFilter.mode(_color, _transferMode))
        ..isAntiAlias = false;
    }
    return _cachedPaint;
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      canvas.saveLayer(offset & size, _paint);
      canvas.paintChild(child, offset.toPoint());
      canvas.restore();
    }
  }
}

class RenderClipRect extends RenderProxyBox {
  RenderClipRect({ RenderBox child }) : super(child);

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      canvas.save();
      canvas.clipRect(offset & size);
      canvas.paintChild(child, offset.toPoint());
      canvas.restore();
    }
  }
}

class RenderClipRRect extends RenderProxyBox {
  RenderClipRRect({ RenderBox child, double xRadius, double yRadius })
    : _xRadius = xRadius, _yRadius = yRadius, super(child) {
    assert(_xRadius != null);
    assert(_yRadius != null);
  }

  double _xRadius;
  double get xRadius => _xRadius;
  void set xRadius (double value) {
    assert(value != null);
    if (_xRadius == value)
      return;
    _xRadius = value;
    markNeedsPaint();
  }

  double _yRadius;
  double get yRadius => _yRadius;
  void set yRadius (double value) {
    assert(value != null);
    if (_yRadius == value)
      return;
    _yRadius = value;
    markNeedsPaint();
  }

  final Paint _paint = new Paint()..isAntiAlias = false;

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      Rect rect = offset & size;
      canvas.saveLayer(rect, _paint);
      sky.RRect rrect = new sky.RRect()..setRectXY(rect, xRadius, yRadius);
      canvas.clipRRect(rrect);
      canvas.paintChild(child, offset.toPoint());
      canvas.restore();
    }
  }
}

class RenderClipOval extends RenderProxyBox {
  RenderClipOval({ RenderBox child }) : super(child);

  final Paint _paint = new Paint()..isAntiAlias = false;

  Rect _cachedRect;
  Path _cachedPath;

  Path _getPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = new Path()..addOval(_cachedRect);
    }
    return _cachedPath;
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      Rect rect = offset & size;
      canvas.saveLayer(rect, _paint);
      canvas.clipPath(_getPath(rect));
      canvas.paintChild(child, offset.toPoint());
      canvas.restore();
    }
  }
}

abstract class RenderShiftedBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {

  // Abstract class for one-child-layout render boxes

  RenderShiftedBox(RenderBox child) {
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
    double result;
    if (child != null) {
      assert(!needsLayout);
      result = child.getDistanceToActualBaseline(baseline);
      assert(child.parentData is BoxParentData);
      if (result != null)
        result += child.parentData.position.y;
    } else {
      result = super.computeDistanceToActualBaseline(baseline);
    }
    return result;
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null)
      canvas.paintChild(child, child.parentData.position + offset);
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    if (child != null) {
      assert(child.parentData is BoxParentData);
      Rect childBounds = child.parentData.position & child.size;
      if (childBounds.contains(position)) {
        child.hitTest(result, position: new Point(position.x - child.parentData.position.x,
                                                      position.y - child.parentData.position.y));
      }
    }
  }

}

class RenderPadding extends RenderShiftedBox {

  RenderPadding({ EdgeDims padding, RenderBox child }) : super(child) {
    assert(padding != null);
    this.padding = padding;
  }

  EdgeDims _padding;
  EdgeDims get padding => _padding;
  void set padding (EdgeDims value) {
    assert(value != null);
    if (_padding == value)
      return;
    _padding = value;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    double totalPadding = padding.left + padding.right;
    if (child != null)
      return child.getMinIntrinsicWidth(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainWidth(totalPadding);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    double totalPadding = padding.left + padding.right;
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainWidth(totalPadding);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    double totalPadding = padding.top + padding.bottom;
    if (child != null)
      return child.getMinIntrinsicHeight(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainHeight(totalPadding);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    double totalPadding = padding.top + padding.bottom;
    if (child != null)
      return child.getMaxIntrinsicHeight(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainHeight(totalPadding);
  }

  void performLayout() {
    assert(padding != null);
    if (child == null) {
      size = constraints.constrain(new Size(
        padding.left + padding.right,
        padding.top + padding.bottom
      ));
      return;
    }
    BoxConstraints innerConstraints = constraints.deflate(padding);
    child.layout(innerConstraints, parentUsesSize: true);
    assert(child.parentData is BoxParentData);
    child.parentData.position = new Point(padding.left, padding.top);
    size = constraints.constrain(new Size(
      padding.left + child.size.width + padding.right,
      padding.top + child.size.height + padding.bottom
    ));
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}padding: ${padding}\n';
}

class RenderPositionedBox extends RenderShiftedBox {

  // This box aligns a child box within itself. It's only useful for
  // children that don't always size to fit their parent. For example,
  // to align a box at the bottom right, you would pass this box a
  // tight constraint that is bigger than the child's natural size,
  // with horizontal and vertical set to 1.0.

  RenderPositionedBox({
    RenderBox child,
    double horizontal: 0.5,
    double vertical: 0.5
  }) : _horizontal = horizontal,
       _vertical = vertical,
       super(child) {
    assert(horizontal != null);
    assert(vertical != null);
  }

  double _horizontal;
  double get horizontal => _horizontal;
  void set horizontal (double value) {
    assert(value != null);
    if (_horizontal == value)
      return;
    _horizontal = value;
    markNeedsLayout();
  }

  double _vertical;
  double get vertical => _vertical;
  void set vertical (double value) {
    assert(value != null);
    if (_vertical == value)
      return;
    _vertical = value;
    markNeedsLayout();
  }

  void performLayout() {
    if (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(child.size);
      assert(child.parentData is BoxParentData);
      Offset delta = size - child.size;
      child.parentData.position = (delta.scale(horizontal, vertical)).toPoint();
    } else {
      performResize();
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}horizontal: ${horizontal}\n${prefix}vertical: ${vertical}\n';
}

class RenderBaseline extends RenderShiftedBox {

  RenderBaseline({
    RenderBox child,
    double baseline,
    TextBaseline baselineType
  }) : _baseline = baseline,
       _baselineType = baselineType,
       super(child) {
    assert(baseline != null);
    assert(baselineType != null);
  }

  double _baseline;
  double get baseline => _baseline;
  void set baseline (double value) {
    assert(value != null);
    if (_baseline == value)
      return;
    _baseline = value;
    markNeedsLayout();
  }

  TextBaseline _baselineType;
  TextBaseline get baselineType => _baselineType;
  void set baselineType (TextBaseline value) {
    assert(value != null);
    if (_baselineType == value)
      return;
    _baselineType = value;
    markNeedsLayout();
  }

  void performLayout() {
    if (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(child.size);
      assert(child.parentData is BoxParentData);
      double delta = baseline - child.getDistanceToBaseline(baselineType);
      child.parentData.position = new Point(0.0, delta);
    } else {
      performResize();
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}baseline: ${baseline}\nbaselineType: ${baselineType}';
}

enum ScrollDirection { horizontal, vertical, both }

class RenderViewport extends RenderBox with RenderObjectWithChildMixin<RenderBox> {

  RenderViewport({
    RenderBox child,
    Offset scrollOffset,
    ScrollDirection scrollDirection: ScrollDirection.vertical
  }) : _scrollOffset = scrollOffset,
       _scrollDirection = scrollDirection {
    assert(_offsetIsSane(scrollOffset, scrollDirection));
    this.child = child;
  }

  bool _offsetIsSane(Offset offset, ScrollDirection direction) {
    switch (direction) {
      case ScrollDirection.both:
        return true;
      case ScrollDirection.horizontal:
        return offset.dy == 0.0;
      case ScrollDirection.vertical:
        return offset.dx == 0.0;
    }
  }

  Offset _scrollOffset;
  Offset get scrollOffset => _scrollOffset;
  void set scrollOffset(Offset value) {
    if (value == _scrollOffset)
      return;
    assert(_offsetIsSane(value, scrollDirection));
    _scrollOffset = value;
    markNeedsPaint();
  }

  ScrollDirection _scrollDirection;
  ScrollDirection get scrollDirection => _scrollDirection;
  void set scrollDirection(ScrollDirection value) {
    if (value == _scrollDirection)
      return;
    assert(_offsetIsSane(scrollOffset, value));
    _scrollDirection = value;
    markNeedsLayout();
  }

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    BoxConstraints innerConstraints;
    switch (scrollDirection) {
      case ScrollDirection.both:
        innerConstraints = new BoxConstraints();
        break;
      case ScrollDirection.horizontal:
        innerConstraints = constraints.heightConstraints();
        break;
      case ScrollDirection.vertical:
        innerConstraints = constraints.widthConstraints();
        break;
    }
    return innerConstraints;
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicWidth(_getInnerConstraints(constraints));
    return super.getMinIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(_getInnerConstraints(constraints));
    return super.getMaxIntrinsicWidth(constraints);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(_getInnerConstraints(constraints));
    return super.getMinIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicHeight(_getInnerConstraints(constraints));
    return super.getMaxIntrinsicHeight(constraints);
  }

  // We don't override computeDistanceToActualBaseline(), because we
  // want the default behaviour (returning null). Otherwise, as you
  // scroll the RenderViewport, it would shift in its parent if the
  // parent was baseline-aligned, which makes no sense.

  void performLayout() {
    if (child != null) {
      child.layout(_getInnerConstraints(constraints), parentUsesSize: true);
      size = constraints.constrain(child.size);
      assert(child.parentData is BoxParentData);
      child.parentData.position = Point.origin;
    } else {
      performResize();
    }
  }

  Offset get _scrollOffsetRoundedToIntegerDevicePixels {
    double devicePixelRatio = sky.view.devicePixelRatio;
    int dxInDevicePixels = (scrollOffset.dx * devicePixelRatio).round();
    int dyInDevicePixels = (scrollOffset.dy * devicePixelRatio).round();
    return new Offset(dxInDevicePixels / devicePixelRatio,
                      dyInDevicePixels / devicePixelRatio);
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null) {
      Offset roundedScrollOffset = _scrollOffsetRoundedToIntegerDevicePixels;
      bool _needsClip = offset < Offset.zero ||
                        !(offset & size).contains(((offset - roundedScrollOffset) & child.size).bottomRight);
      if (_needsClip) {
        canvas.save();
        canvas.clipRect(offset & size);
      }
      canvas.paintChild(child, (offset - roundedScrollOffset).toPoint());
      if (_needsClip)
        canvas.restore();
    }
  }

  void applyPaintTransform(Matrix4 transform) {
    super.applyPaintTransform(transform);
    transform.translate(-scrollOffset.dx, -scrollOffset.dy);
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    if (child != null) {
      assert(child.parentData is BoxParentData);
      Rect childBounds = child.parentData.position & child.size;
      Point transformedPosition = position + _scrollOffsetRoundedToIntegerDevicePixels;
      if (childBounds.contains(transformedPosition))
        child.hitTest(result, position: transformedPosition);
    }
  }
}

class RenderImage extends RenderBox {

  RenderImage({ sky.Image image, double width, double height, sky.ColorFilter colorFilter })
    : _image = image,
      _width = width,
      _height = height,
      _colorFilter = colorFilter;

  sky.Image _image;
  sky.Image get image => _image;
  void set image (sky.Image value) {
    if (value == _image)
      return;
    _image = value;
    markNeedsPaint();
    if (_width == null || _height == null)
      markNeedsLayout();
  }

  double _width;
  double get width => _width;
  void set width (double value) {
    if (value == _width)
      return;
    _width = value;
    markNeedsLayout();
  }

  double _height;
  double get height => _height;
  void set height (double value) {
    if (value == _height)
      return;
    _height = value;
    markNeedsLayout();
  }

  sky.ColorFilter _colorFilter;
  sky.ColorFilter get colorFilter => _colorFilter;
  void set colorFilter (sky.ColorFilter value) {
    if (value == _colorFilter)
      return;
    _colorFilter = value;
    _cachedPaint = null;
    markNeedsPaint();
  }

  Paint _cachedPaint;
  Paint get _paint {
    if (_cachedPaint == null) {
      _cachedPaint = new Paint();
      if (colorFilter != null)
        _cachedPaint.setColorFilter(colorFilter);
    }
    return _cachedPaint;
  }

  Size _sizeForConstraints(BoxConstraints constraints) {
    // If there's no image, we can't size ourselves automatically
    if (_image == null) {
      double width = _width == null ? 0.0 : _width;
      double height = _height == null ? 0.0 : _height;
      return constraints.constrain(new Size(width, height));
    }

    if (!constraints.isTight) {
      // If neither height nor width are specified, use inherent image
      // dimensions. If only one dimension is specified, adjust the
      // other dimension to maintain the aspect ratio. In both cases,
      // constrain dimensions first, otherwise we end up losing the
      // ratio after constraining.
      if (_width == null) {
        if (_height == null) {
          // autosize
          double width = constraints.constrainWidth(_image.width.toDouble());
          double maxHeight = constraints.constrainHeight(_image.height.toDouble());
          double ratio = _image.height / _image.width;
          double height = width * ratio;
          if (height > maxHeight) {
            height = maxHeight;
            width = maxHeight / ratio;
          }
          return constraints.constrain(new Size(width, height));
        }
        // Determine width from height
        double width = _height * _image.width / _image.height;
        return constraints.constrain(new Size(width, height));
      }
      if (_height == null) {
        // Determine height from width
        double height = _width * _image.height / _image.width;
        return constraints.constrain(new Size(width, height));
      }
    }
    return constraints.constrain(new Size(_image.width.toDouble(), _image.height.toDouble()));
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (_width == null && _height == null)
      return constraints.constrainWidth(0.0);
    return _sizeForConstraints(constraints).width;
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return _sizeForConstraints(constraints).width;
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (_width == null && _height == null)
      return constraints.constrainHeight(0.0);
    return _sizeForConstraints(constraints).height;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return _sizeForConstraints(constraints).height;
  }

  void performLayout() {
    size = _sizeForConstraints(constraints);
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (_image == null)
      return;
    bool needsScale = size.width != _image.width || size.height != _image.height;
    if (needsScale) {
      double widthScale = size.width / _image.width;
      double heightScale = size.height / _image.height;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(widthScale, heightScale);
      offset = Offset.zero;
    }
    canvas.drawImage(_image, offset.toPoint(), _paint);
    if (needsScale)
      canvas.restore();
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}width: ${width}\n${prefix}height: ${height}\n';
}

class RenderDecoratedBox extends RenderProxyBox {

  RenderDecoratedBox({
    BoxDecoration decoration,
    RenderBox child
  }) : _painter = new BoxPainter(decoration), super(child);

  BoxPainter _painter;
  BoxDecoration get decoration => _painter.decoration;
  void set decoration (BoxDecoration value) {
    assert(value != null);
    if (_painter.decoration.backgroundImage != null)
      _painter.decoration.backgroundImage.removeChangeListener(markNeedsPaint);
    if (value.backgroundImage != null)
      value.backgroundImage.addChangeListener(markNeedsPaint);
    if (value == _painter.decoration)
      return;
    _painter.decoration = value;
    markNeedsPaint();
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    assert(size.width != null);
    assert(size.height != null);
    _painter.paint(canvas, offset & size);
    super.paint(canvas, offset);
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}decoration:\n${_painter.decoration.toString(prefix + "  ")}\n';
}

class RenderTransform extends RenderProxyBox {
  RenderTransform({
    Matrix4 transform,
    RenderBox child
  }) : super(child) {
    assert(transform != null);
    this.transform = transform;
  }

  Matrix4 _transform;

  void set transform(Matrix4 value) {
    assert(value != null);
    if (_transform == value)
      return;
    _transform = new Matrix4.copy(value);
    markNeedsPaint();
  }

  void setIdentity() {
    _transform.setIdentity();
    markNeedsPaint();
  }

  void rotateX(double radians) {
    _transform.rotateX(radians);
    markNeedsPaint();
  }

  void rotateY(double radians) {
    _transform.rotateY(radians);
    markNeedsPaint();
  }

  void rotateZ(double radians) {
    _transform.rotateZ(radians);
    markNeedsPaint();
  }

  void translate(x, [double y = 0.0, double z = 0.0]) {
    _transform.translate(x, y, z);
    markNeedsPaint();
  }

  void scale(x, [double y, double z]) {
    _transform.scale(x, y, z);
    markNeedsPaint();
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    Matrix4 inverse = new Matrix4.zero();
    /* double det = */ inverse.copyInverse(_transform);
    // TODO(abarth): Check the determinant for degeneracy.

    Vector3 position3 = new Vector3(position.x, position.y, 0.0);
    Vector3 transformed3 = inverse.transform3(position3);
    Point transformed = new Point(transformed3.x, transformed3.y);
    super.hitTestChildren(result, position: transformed);
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.concat(_transform.storage);
    super.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void applyPaintTransform(Matrix4 transform) {
    super.applyPaintTransform(transform);
    transform.multiply(_transform);
  }

  String debugDescribeSettings(String prefix) {
    List<String> result = _transform.toString().split('\n').map((s) => '$prefix  $s\n').toList();
    result.removeLast();
    return '${super.debugDescribeSettings(prefix)}${prefix}transform matrix:\n${result.join()}';
  }
}

typedef void SizeChangedCallback(Size newSize);

class RenderSizeObserver extends RenderProxyBox {
  RenderSizeObserver({
    this.callback,
    RenderBox child
  }) : super(child) {
    assert(callback != null);
  }

  SizeChangedCallback callback;

  void performLayout() {
    Size oldSize = size;

    super.performLayout();

    if (oldSize != size)
      callback(size);
  }
}

typedef void CustomPaintCallback(PaintingCanvas canvas, Size size);

class RenderCustomPaint extends RenderProxyBox {

  RenderCustomPaint({
    CustomPaintCallback callback,
    RenderBox child
  }) : super(child) {
    assert(callback != null);
    _callback = callback;
  }

  CustomPaintCallback _callback;
  void set callback (CustomPaintCallback value) {
    assert(value != null || !attached);
    if (_callback == value)
      return;
    _callback = value;
    markNeedsPaint();
  }

  void attach() {
    assert(_callback != null);
    super.attach();
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    assert(_callback != null);
    canvas.translate(offset.dx, offset.dy);
    _callback(canvas, size);
    super.paint(canvas, Offset.zero);
    canvas.translate(-offset.dx, -offset.dy);
  }
}

// RENDER VIEW LAYOUT MANAGER

class ViewConstraints {
  const ViewConstraints({
    this.size: Size.zero,
    this.orientation
  });
  final Size size;
  final int orientation;
}

class RenderView extends RenderObject with RenderObjectWithChildMixin<RenderBox> {
  bool get createNewDisplayList => true;

  RenderView({
    RenderBox child,
    this.timeForRotation: const Duration(microseconds: 83333)
  }) {
    this.child = child;
  }

  Size _size = Size.zero;
  Size get size => _size;

  int _orientation; // 0..3
  int get orientation => _orientation;
  Duration timeForRotation;

  ViewConstraints _rootConstraints;
  ViewConstraints get rootConstraints => _rootConstraints;
  void set rootConstraints(ViewConstraints value) {
    if (_rootConstraints == value)
      return;
    _rootConstraints = value;
    markNeedsLayout();
  }

  // We never call layout() on this class, so this should never get
  // checked. (This class is laid out using scheduleInitialLayout().)
  bool debugDoesMeetConstraints() { assert(false); return false; }

  void performResize() {
    assert(false);
  }

  void performLayout() {
    if (_rootConstraints.orientation != _orientation) {
      if (_orientation != null && child != null)
        child.rotate(oldAngle: _orientation, newAngle: _rootConstraints.orientation, time: timeForRotation);
      _orientation = _rootConstraints.orientation;
    }
    _size = _rootConstraints.size;
    assert(!_size.isInfinite);

    if (child != null)
      child.layout(new BoxConstraints.tight(_size));
  }

  void rotate({ int oldAngle, int newAngle, Duration time }) {
    assert(false); // nobody tells the screen to rotate, the whole rotate() dance is started from our performResize()
  }

  bool hitTest(HitTestResult result, { Point position }) {
    if (child != null) {
      Rect childBounds = Point.origin & child.size;
      if (childBounds.contains(position))
        child.hitTest(result, position: position);
    }
    result.add(new HitTestEntry(this));
    return true;
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    if (child != null)
      canvas.paintChild(child, offset.toPoint());
  }

  void paintFrame() {
    sky.tracing.begin('RenderView.paintFrame');
    try {
      double devicePixelRatio = sky.view.devicePixelRatio;
      sky.PictureRecorder recorder = new sky.PictureRecorder();
      Rect cullRect = Point.origin & (size * devicePixelRatio);
      PaintingCanvas canvas = new PaintingCanvas(recorder, cullRect);
      canvas.drawColor(const Color(0xFF000000), sky.TransferMode.src);
      canvas.scale(devicePixelRatio, devicePixelRatio);
      canvas.paintChild(child, Point.origin);
      sky.view.picture = recorder.endRecording();
    } finally {
      sky.tracing.end('RenderView.paintFrame');
    }
  }

  Rect get paintBounds => Point.origin & size;
}

class RenderIgnorePointer extends RenderProxyBox {
  RenderIgnorePointer({ RenderBox child }) : super(child);
  bool hitTest(HitTestResult result, { Point position }) {
    return false;
  }
}

// HELPER METHODS FOR RENDERBOX CONTAINERS
abstract class RenderBoxContainerDefaultsMixin<ChildType extends RenderBox, ParentDataType extends ContainerParentDataMixin<ChildType>> implements ContainerRenderObjectMixin<ChildType, ParentDataType> {

  // This class, by convention, doesn't override any members of the superclass.
  // It only provides helper functions that subclasses can call.

  double defaultComputeDistanceToFirstActualBaseline(TextBaseline baseline) {
    assert(!needsLayout);
    RenderBox child = firstChild;
    while (child != null) {
      assert(child.parentData is ParentDataType);
      double result = child.getDistanceToActualBaseline(baseline);
      if (result != null)
        return result + child.parentData.position.y;
      child = child.parentData.nextSibling;
    }
    return null;
  }

  double defaultComputeDistanceToHighestActualBaseline(TextBaseline baseline) {
    assert(!needsLayout);
    double result;
    RenderBox child = firstChild;
    while (child != null) {
      assert(child.parentData is ParentDataType);
      double candidate = child.getDistanceToActualBaseline(baseline);
      if (candidate != null) {
        candidate += child.parentData.position.y;
        if (result != null)
          result = math.min(result, candidate);
        else
          result = candidate;
      }
      child = child.parentData.nextSibling;
    }
    return result;
  }

  void defaultHitTestChildren(HitTestResult result, { Point position }) {
    // the x, y parameters have the top left of the node's box as the origin
    ChildType child = lastChild;
    while (child != null) {
      assert(child.parentData is ParentDataType);
      Rect childBounds = child.parentData.position & child.size;
      if (childBounds.contains(position)) {
        if (child.hitTest(result, position: new Point(position.x - child.parentData.position.x,
                                                          position.y - child.parentData.position.y)))
          break;
      }
      child = child.parentData.previousSibling;
    }
  }

  void defaultPaint(PaintingCanvas canvas, Offset offset) {
    RenderBox child = firstChild;
    while (child != null) {
      assert(child.parentData is ParentDataType);
      canvas.paintChild(child, child.parentData.position + offset);
      child = child.parentData.nextSibling;
    }
  }
}
