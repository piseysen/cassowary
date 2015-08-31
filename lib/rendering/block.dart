// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:sky/rendering/box.dart';
import 'package:sky/rendering/object.dart';
import 'package:vector_math/vector_math.dart';

class BlockParentData extends BoxParentData with ContainerParentDataMixin<RenderBox> { }

enum BlockDirection { horizontal, vertical }

typedef double _ChildSizingFunction(RenderBox child, BoxConstraints constraints);
typedef double _Constrainer(double value);

abstract class RenderBlockBase extends RenderBox with ContainerRenderObjectMixin<RenderBox, BlockParentData>,
                                                      RenderBoxContainerDefaultsMixin<RenderBox, BlockParentData> {

  // lays out RenderBox children in a vertical stack
  // uses the maximum width provided by the parent

  RenderBlockBase({
    List<RenderBox> children,
    BlockDirection direction: BlockDirection.vertical,
    double itemExtent,
    double minExtent: 0.0
  }) : _direction = direction, _itemExtent = itemExtent, _minExtent = minExtent {
    addAll(children);
  }

  void setupParentData(RenderBox child) {
    if (child.parentData is! BlockParentData)
      child.parentData = new BlockParentData();
  }

  BlockDirection _direction;
  BlockDirection get direction => _direction;
  void set direction (BlockDirection value) {
    if (_direction != value) {
      _direction = value;
      markNeedsLayout();
    }
  }

  double _itemExtent;
  double get itemExtent => _itemExtent;
  void set itemExtent(double value) {
    if (value != _itemExtent) {
      _itemExtent = value;
      markNeedsLayout();
    }
  }

  double _minExtent;
  double get minExtent => _minExtent;
  void set minExtent(double value) {
    if (value != _minExtent) {
      _minExtent = value;
      markNeedsLayout();
    }
  }

  bool get isVertical => _direction == BlockDirection.vertical;

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    if (isVertical)
      return new BoxConstraints.tightFor(width: constraints.constrainWidth(constraints.maxWidth),
                                         height: itemExtent);
    return new BoxConstraints.tightFor(height: constraints.constrainHeight(constraints.maxHeight),
                                       width: itemExtent);
  }

  double get _mainAxisExtent {
    RenderBox child = lastChild;
    if (child == null)
      return minExtent;
    BoxParentData parentData = child.parentData;
    return isVertical ?
        math.max(minExtent, parentData.position.y + child.size.height) :
        math.max(minExtent, parentData.position.x + child.size.width);
  }

  void performLayout() {
    BoxConstraints innerConstraints = _getInnerConstraints(constraints);
    double position = 0.0;
    RenderBox child = firstChild;
    while (child != null) {
      child.layout(innerConstraints, parentUsesSize: true);
      assert(child.parentData is BlockParentData);
      child.parentData.position = isVertical ? new Point(0.0, position) : new Point(position, 0.0);
      position += isVertical ? child.size.height : child.size.width;
      child = child.parentData.nextSibling;
    }
    size = isVertical ?
        constraints.constrain(new Size(constraints.maxWidth, _mainAxisExtent)) :
        constraints.constrain(new Size(_mainAxisExtent, constraints.maxHeight));
    assert(!size.isInfinite);
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}direction: ${direction}\n';
}

class RenderBlock extends RenderBlockBase {

  RenderBlock({
    List<RenderBox> children,
    BlockDirection direction: BlockDirection.vertical,
    double itemExtent,
    double minExtent: 0.0
  }) : super(children: children, direction: direction, itemExtent: itemExtent, minExtent: minExtent);

  double _getIntrinsicCrossAxis(BoxConstraints constraints, _ChildSizingFunction childSize) {
    double extent = 0.0;
    BoxConstraints innerConstraints = isVertical ? constraints.widthConstraints() : constraints.heightConstraints();
    RenderBox child = firstChild;
    while (child != null) {
      extent = math.max(extent, childSize(child, innerConstraints));
      assert(child.parentData is BlockParentData);
      child = child.parentData.nextSibling;
    }
    return extent;
  }

  double _getIntrinsicMainAxis(BoxConstraints constraints) {
    double extent = 0.0;
    BoxConstraints innerConstraints = _getInnerConstraints(constraints);
    RenderBox child = firstChild;
    while (child != null) {
      double childExtent = isVertical ?
        child.getMinIntrinsicHeight(innerConstraints) :
        child.getMinIntrinsicWidth(innerConstraints);
      assert(() {
        if (isVertical)
          return childExtent == child.getMaxIntrinsicHeight(innerConstraints);
        return childExtent == child.getMaxIntrinsicWidth(innerConstraints);
      });
      extent += childExtent;
      assert(child.parentData is BlockParentData);
      child = child.parentData.nextSibling;
    }
    return math.max(extent, minExtent);
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (isVertical) {
      return _getIntrinsicCrossAxis(constraints,
        (c, innerConstraints) => c.getMinIntrinsicWidth(innerConstraints));
    }
    return _getIntrinsicMainAxis(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (isVertical) {
      return _getIntrinsicCrossAxis(constraints,
          (c, innerConstraints) => c.getMaxIntrinsicWidth(innerConstraints));
    }
    return _getIntrinsicMainAxis(constraints);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (isVertical)
      return _getIntrinsicMainAxis(constraints);
    return _getIntrinsicCrossAxis(constraints,
        (c, innerConstraints) => c.getMinIntrinsicWidth(innerConstraints));
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (isVertical)
      return _getIntrinsicMainAxis(constraints);
    return _getIntrinsicCrossAxis(constraints,
        (c, innerConstraints) => c.getMaxIntrinsicWidth(innerConstraints));
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  void performLayout() {
    assert((isVertical ? constraints.maxHeight >= double.INFINITY : constraints.maxWidth >= double.INFINITY) &&
           'RenderBlock does not clip or resize its children, so it must be placed in a parent that does not constrain ' +
           'the block\'s main direction. You probably want to put the RenderBlock inside a RenderViewport.' is String);
    super.performLayout();
  }

  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    defaultHitTestChildren(result, position: position);
  }

}

class RenderBlockViewport extends RenderBlockBase {

  // This class invokes a callbacks for layout and intrinsic
  // dimensions. The main callback (constructor argument and property
  // called "callback") is expected to modify the element's child
  // list. The regular block layout algorithm is then applied to the
  // children. The intrinsic dimension callbacks are called to
  // determine intrinsic dimensions; if no value can be returned, they
  // should not be set or, if set, should return null.

  RenderBlockViewport({
    LayoutCallback callback,
    DimensionCallback totalExtentCallback,
    DimensionCallback maxCrossAxisDimensionCallback,
    DimensionCallback minCrossAxisDimensionCallback,
    BlockDirection direction: BlockDirection.vertical,
    double itemExtent,
    double minExtent: 0.0,
    double startOffset: 0.0,
    List<RenderBox> children
  }) : _callback = callback,
       _totalExtentCallback = totalExtentCallback,
       _maxCrossAxisDimensionCallback = maxCrossAxisDimensionCallback,
       _minCrossAxisDimensionCallback = minCrossAxisDimensionCallback,
       _startOffset = startOffset,
       super(children: children, direction: direction, itemExtent: itemExtent, minExtent: minExtent);

  bool _inCallback = false;

  // Called during layout. Mutate the child list appropriately.
  LayoutCallback _callback;
  LayoutCallback get callback => _callback;
  void set callback(LayoutCallback value) {
    assert(!_inCallback);
    if (value == _callback)
      return;
    _callback = value;
    markNeedsLayout();
  }

  // Return the sum of the extent of all the children that could be included by the callback in one go.
  // The extent is the dimension in the direction given by the 'direction' property.
  DimensionCallback _totalExtentCallback;
  DimensionCallback get totalExtentCallback => _totalExtentCallback;
  void set totalExtentCallback(DimensionCallback value) {
    assert(!_inCallback);
    if (value == _totalExtentCallback)
      return;
    _totalExtentCallback = value;
    markNeedsLayout();
  }

  // Return the minimum dimension across all the children that could
  // be included in one go, in the direction orthogonal to that given
  // by the 'direction' property.
  DimensionCallback _minCrossAxisDimensionCallback;
  DimensionCallback get minCrossAxisDimensionCallback => _minCrossAxisDimensionCallback;
  void set minCrossAxisDimensionCallback(DimensionCallback value) {
    assert(!_inCallback);
    if (value == _minCrossAxisDimensionCallback)
      return;
    _minCrossAxisDimensionCallback = value;
    markNeedsLayout();
  }

  // Return the maximum dimension across all the children that could
  // be included in one go, in the direction orthogonal to that given
  // by the 'direction' property.
  DimensionCallback _maxCrossAxisDimensionCallback;
  DimensionCallback get maxCrossAxisDimensionCallback => _maxCrossAxisDimensionCallback;
  void set maxCrossAxisDimensionCallback(DimensionCallback value) {
    assert(!_inCallback);
    if (value == _maxCrossAxisDimensionCallback)
      return;
    _maxCrossAxisDimensionCallback = value;
    markNeedsLayout();
  }

  // you can set this from within the callback if necessary
  double _startOffset;
  double get startOffset => _startOffset;
  void set startOffset(double value) {
    if (value != _startOffset) {
      _startOffset = value;
      markNeedsPaint();
    }
  }

  double _getIntrinsicDimension(BoxConstraints constraints, DimensionCallback intrinsicCallback, _Constrainer constrainer) {
    assert(!_inCallback);
    double result;
    if (intrinsicCallback == null) {
      assert(() {
        'RenderBlockViewport does not support returning intrinsic dimensions if the relevant callbacks have not been specified.';
        return false;
      });
      return constrainer(0.0);
    }
    try {
      _inCallback = true;
      result = intrinsicCallback(constraints);
      if (result == null)
        result = constrainer(0.0);
      else
        result = constrainer(result);
    } finally {
      _inCallback = false;
    }
    return result;
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (isVertical)
      return _getIntrinsicDimension(constraints, minCrossAxisDimensionCallback, constraints.constrainWidth);
    return constraints.constrainWidth(minExtent);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (isVertical)
      return _getIntrinsicDimension(constraints, maxCrossAxisDimensionCallback, constraints.constrainWidth);
    return _getIntrinsicDimension(constraints, totalExtentCallback, new BoxConstraints(minWidth: minExtent).apply(constraints).constrainWidth);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (!isVertical)
      return _getIntrinsicDimension(constraints, minCrossAxisDimensionCallback, constraints.constrainHeight);
    return constraints.constrainHeight(0.0);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (!isVertical)
      return _getIntrinsicDimension(constraints, maxCrossAxisDimensionCallback, constraints.constrainHeight);
    return _getIntrinsicDimension(constraints, totalExtentCallback, new BoxConstraints(minHeight: minExtent).apply(constraints).constrainHeight);
  }

  // We don't override computeDistanceToActualBaseline(), because we
  // want the default behaviour (returning null). Otherwise, as you
  // scroll the RenderBlockViewport, it would shift in its parent if
  // the parent was baseline-aligned, which makes no sense.

  bool get debugDoesLayoutWithCallback => true;
  void performLayout() {
    if (_callback != null) {
      try {
        _inCallback = true;
        invokeLayoutCallback(_callback);
      } finally {
        _inCallback = false;
      }
    }
    super.performLayout();
  }

  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.clipRect(offset & size);
    if (isVertical)
      defaultPaint(context, offset.translate(0.0, startOffset));
    else
      defaultPaint(context, offset.translate(startOffset, 0.0));
    context.canvas.restore();
  }

  void applyPaintTransform(Matrix4 transform) {
    super.applyPaintTransform(transform);
    transform.translate(0.0, startOffset);
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    defaultHitTestChildren(result, position: position + new Offset(0.0, -startOffset));
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}startOffset: ${startOffset}\n';
}
