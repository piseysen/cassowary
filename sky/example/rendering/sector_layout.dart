// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:sky' as sky;

import 'package:sky/rendering/box.dart';
import 'package:sky/rendering/object.dart';
import 'package:sky/rendering/sky_binding.dart';

const double kTwoPi = 2 * math.PI;

class SectorConstraints extends Constraints {
  const SectorConstraints({
    this.minDeltaRadius: 0.0,
    this.maxDeltaRadius: double.INFINITY,
    this.minDeltaTheta: 0.0,
    this.maxDeltaTheta: kTwoPi
  });

  const SectorConstraints.tight({ double deltaRadius: 0.0, double deltaTheta: 0.0 })
    : minDeltaRadius = deltaRadius,
      maxDeltaRadius = deltaRadius,
      minDeltaTheta = deltaTheta,
      maxDeltaTheta = deltaTheta;

  final double minDeltaRadius;
  final double maxDeltaRadius;
  final double minDeltaTheta;
  final double maxDeltaTheta;

  double constrainDeltaRadius(double deltaRadius) {
    return clamp(min: minDeltaRadius, max: maxDeltaRadius, value: deltaRadius);
  }

  double constrainDeltaTheta(double deltaTheta) {
    return clamp(min: minDeltaTheta, max: maxDeltaTheta, value: deltaTheta);
  }

  bool get isTight => minDeltaTheta >= maxDeltaTheta && minDeltaTheta >= maxDeltaTheta;
}

class SectorDimensions {
  const SectorDimensions({ this.deltaRadius: 0.0, this.deltaTheta: 0.0 });

  factory SectorDimensions.withConstraints(
    SectorConstraints constraints,
    { double deltaRadius: 0.0, double deltaTheta: 0.0 }
  ) {
    return new SectorDimensions(
      deltaRadius: constraints.constrainDeltaRadius(deltaRadius),
      deltaTheta: constraints.constrainDeltaTheta(deltaTheta)
    );
  }

  final double deltaRadius;
  final double deltaTheta;
}

class SectorParentData extends ParentData {
  double radius = 0.0;
  double theta = 0.0;
}

abstract class RenderSector extends RenderObject {

  void setupParentData(RenderObject child) {
    if (child.parentData is! SectorParentData)
      child.parentData = new SectorParentData();
  }

  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    return new SectorDimensions.withConstraints(constraints);
  }

  SectorConstraints get constraints => super.constraints;
  bool debugDoesMeetConstraints() {
    assert(constraints != null);
    assert(deltaRadius != null);
    assert(deltaRadius < double.INFINITY);
    assert(deltaTheta != null);
    assert(deltaTheta < double.INFINITY);
    return constraints.minDeltaRadius <= deltaRadius &&
           deltaRadius <= math.max(constraints.minDeltaRadius, constraints.maxDeltaRadius) &&
           constraints.minDeltaTheta <= deltaTheta &&
           deltaTheta <= math.max(constraints.minDeltaTheta, constraints.maxDeltaTheta);
  }
  void performResize() {
    // default behaviour for subclasses that have sizedByParent = true
    deltaRadius = constraints.constrainDeltaRadius(0.0);
    deltaTheta = constraints.constrainDeltaTheta(0.0);
  }
  void performLayout() {
    // descendants have to either override performLayout() to set both
    // the dimensions and lay out children, or, set sizedByParent to
    // true so that performResize()'s logic above does its thing.
    assert(sizedByParent);
  }

  Rect get paintBounds => new Rect.fromLTWH(0.0, 0.0, 2.0 * deltaRadius, 2.0 * deltaRadius);

  bool hitTest(HitTestResult result, { double radius, double theta }) {
    assert(parentData is SectorParentData);
    if (radius < parentData.radius || radius >= parentData.radius + deltaRadius ||
        theta < parentData.theta || theta >= parentData.theta + deltaTheta)
      return false;
    hitTestChildren(result, radius: radius, theta: theta);
    result.add(new HitTestEntry(this));
    return true;
  }
  void hitTestChildren(HitTestResult result, { double radius, double theta }) { }

  double deltaRadius;
  double deltaTheta;
}

abstract class RenderDecoratedSector extends RenderSector {

  RenderDecoratedSector(BoxDecoration decoration) : _decoration = decoration;

  BoxDecoration _decoration;
  BoxDecoration get decoration => _decoration;
  void set decoration (BoxDecoration value) {
    if (value == _decoration)
      return;
    _decoration = value;
    markNeedsPaint();
  }

  // offset must point to the center of the circle
  void paint(PaintingCanvas canvas, Offset offset) {
    assert(deltaRadius != null);
    assert(deltaTheta != null);
    assert(parentData is SectorParentData);

    if (_decoration == null)
      return;

    if (_decoration.backgroundColor != null) {
      Paint paint = new Paint()..color = _decoration.backgroundColor;
      Path path = new Path();
      double outerRadius = (parentData.radius + deltaRadius);
      Rect outerBounds = new Rect.fromLTRB(offset.dx-outerRadius, offset.dy-outerRadius, offset.dx+outerRadius, offset.dy+outerRadius);
      path.arcTo(outerBounds, parentData.theta, deltaTheta, true);
      double innerRadius = parentData.radius;
      Rect innerBounds = new Rect.fromLTRB(offset.dx-innerRadius, offset.dy-innerRadius, offset.dx+innerRadius, offset.dy+innerRadius);
      path.arcTo(innerBounds, parentData.theta + deltaTheta, -deltaTheta, false);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

}

class SectorChildListParentData extends SectorParentData with ContainerParentDataMixin<RenderSector> { }

class RenderSectorWithChildren extends RenderDecoratedSector with ContainerRenderObjectMixin<RenderSector, SectorChildListParentData> {
  RenderSectorWithChildren(BoxDecoration decoration) : super(decoration);

  void hitTestChildren(HitTestResult result, { double radius, double theta }) {
    RenderSector child = lastChild;
    while (child != null) {
      assert(child.parentData is SectorChildListParentData);
      if (child.hitTest(result, radius: radius, theta: theta))
        return;
      child = child.parentData.previousSibling;
    }
  }
}

class RenderSectorRing extends RenderSectorWithChildren {
  // lays out RenderSector children in a ring

  RenderSectorRing({
    BoxDecoration decoration,
    double deltaRadius: double.INFINITY,
    double padding: 0.0
  }) : super(decoration), _padding = padding, _desiredDeltaRadius = deltaRadius;

  double _desiredDeltaRadius;
  double get desiredDeltaRadius => _desiredDeltaRadius;
  void set desiredDeltaRadius(double value) {
    assert(value != null);
    if (_desiredDeltaRadius != value) {
      _desiredDeltaRadius = value;
      markNeedsLayout();
    }
  }

  double _padding;
  double get padding => _padding;
  void set padding(double value) {
    // TODO(ianh): avoid code duplication
    assert(value != null);
    if (_padding != value) {
      _padding = value;
      markNeedsLayout();
    }
  }

  void setupParentData(RenderObject child) {
    // TODO(ianh): avoid code duplication
    if (child.parentData is! SectorChildListParentData)
      child.parentData = new SectorChildListParentData();
  }

  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    double outerDeltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    double innerDeltaRadius = outerDeltaRadius - padding * 2.0;
    double childRadius = radius + padding;
    double paddingTheta = math.atan(padding / (radius + outerDeltaRadius));
    double innerTheta = paddingTheta; // increments with each child
    double remainingDeltaTheta = constraints.maxDeltaTheta - (innerTheta + paddingTheta);
    RenderSector child = firstChild;
    while (child != null) {
      SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: innerDeltaRadius,
        maxDeltaTheta: remainingDeltaTheta
      );
      SectorDimensions childDimensions = child.getIntrinsicDimensions(innerConstraints, childRadius);
      innerTheta += childDimensions.deltaTheta;
      remainingDeltaTheta -= childDimensions.deltaTheta;
      assert(child.parentData is SectorChildListParentData);
      child = child.parentData.nextSibling;
      if (child != null) {
        innerTheta += paddingTheta;
        remainingDeltaTheta -= paddingTheta;
      }
    }
    return new SectorDimensions.withConstraints(constraints,
                                                deltaRadius: outerDeltaRadius,
                                                deltaTheta: innerTheta);
  }

  void performLayout() {
    assert(this.parentData is SectorParentData);
    deltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    assert(deltaRadius < double.INFINITY);
    double innerDeltaRadius = deltaRadius - padding * 2.0;
    double childRadius = this.parentData.radius + padding;
    double paddingTheta = math.atan(padding / (this.parentData.radius + deltaRadius));
    double innerTheta = paddingTheta; // increments with each child
    double remainingDeltaTheta = constraints.maxDeltaTheta - (innerTheta + paddingTheta);
    RenderSector child = firstChild;
    while (child != null) {
      SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: innerDeltaRadius,
        maxDeltaTheta: remainingDeltaTheta
      );
      assert(child.parentData is SectorParentData);
      child.parentData.theta = innerTheta;
      child.parentData.radius = childRadius;
      child.layout(innerConstraints, parentUsesSize: true);
      innerTheta += child.deltaTheta;
      remainingDeltaTheta -= child.deltaTheta;
      assert(child.parentData is SectorChildListParentData);
      child = child.parentData.nextSibling;
      if (child != null) {
        innerTheta += paddingTheta;
        remainingDeltaTheta -= paddingTheta;
      }
    }
    deltaTheta = innerTheta;
  }

  // offset must point to the center of our circle
  // each sector then knows how to paint itself at its location
  void paint(PaintingCanvas canvas, Offset offset) {
    // TODO(ianh): avoid code duplication
    super.paint(canvas, offset);
    RenderSector child = firstChild;
    while (child != null) {
      assert(child.parentData is SectorChildListParentData);
      canvas.paintChild(child, offset.toPoint());
      child = child.parentData.nextSibling;
    }
  }

}

class RenderSectorSlice extends RenderSectorWithChildren {
  // lays out RenderSector children in a stack

  RenderSectorSlice({
    BoxDecoration decoration,
    double deltaTheta: kTwoPi,
    double padding: 0.0
  }) : super(decoration), _padding = padding, _desiredDeltaTheta = deltaTheta;

  double _desiredDeltaTheta;
  double get desiredDeltaTheta => _desiredDeltaTheta;
  void set desiredDeltaTheta(double value) {
    assert(value != null);
    if (_desiredDeltaTheta != value) {
      _desiredDeltaTheta = value;
      markNeedsLayout();
    }
  }

  double _padding;
  double get padding => _padding;
  void set padding(double value) {
    // TODO(ianh): avoid code duplication
    assert(value != null);
    if (_padding != value) {
      _padding = value;
      markNeedsLayout();
    }
  }

  void setupParentData(RenderObject child) {
    // TODO(ianh): avoid code duplication
    if (child.parentData is! SectorChildListParentData)
      child.parentData = new SectorChildListParentData();
  }

  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    assert(this.parentData is SectorParentData);
    double paddingTheta = math.atan(padding / this.parentData.radius);
    double outerDeltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
    double innerDeltaTheta = outerDeltaTheta - paddingTheta * 2.0;
    double childRadius = this.parentData.radius + padding;
    double remainingDeltaRadius = constraints.maxDeltaRadius - (padding * 2.0);
    RenderSector child = firstChild;
    while (child != null) {
      SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: remainingDeltaRadius,
        maxDeltaTheta: innerDeltaTheta
      );
      SectorDimensions childDimensions = child.getIntrinsicDimensions(innerConstraints, childRadius);
      childRadius += childDimensions.deltaRadius;
      remainingDeltaRadius -= childDimensions.deltaRadius;
      assert(child.parentData is SectorChildListParentData);
      child = child.parentData.nextSibling;
      childRadius += padding;
      remainingDeltaRadius -= padding;
    }
    return new SectorDimensions.withConstraints(constraints,
                                                deltaRadius: childRadius - this.parentData.radius,
                                                deltaTheta: outerDeltaTheta);
  }

  void performLayout() {
    assert(this.parentData is SectorParentData);
    deltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
    assert(deltaTheta <= kTwoPi);
    double paddingTheta = math.atan(padding / this.parentData.radius);
    double innerTheta = this.parentData.theta + paddingTheta;
    double innerDeltaTheta = deltaTheta - paddingTheta * 2.0;
    double childRadius = this.parentData.radius + padding;
    double remainingDeltaRadius = constraints.maxDeltaRadius - (padding * 2.0);
    RenderSector child = firstChild;
    while (child != null) {
      SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: remainingDeltaRadius,
        maxDeltaTheta: innerDeltaTheta
      );
      child.parentData.theta = innerTheta;
      child.parentData.radius = childRadius;
      child.layout(innerConstraints, parentUsesSize: true);
      childRadius += child.deltaRadius;
      remainingDeltaRadius -= child.deltaRadius;
      assert(child.parentData is SectorChildListParentData);
      child = child.parentData.nextSibling;
      childRadius += padding;
      remainingDeltaRadius -= padding;
    }
    deltaRadius = childRadius - this.parentData.radius;
  }

  // offset must point to the center of our circle
  // each sector then knows how to paint itself at its location
  void paint(PaintingCanvas canvas, Offset offset) {
    // TODO(ianh): avoid code duplication
    super.paint(canvas, offset);
    RenderSector child = firstChild;
    while (child != null) {
      assert(child.parentData is SectorChildListParentData);
      canvas.paintChild(child, offset.toPoint());
      child = child.parentData.nextSibling;
    }
  }

}

class RenderBoxToRenderSectorAdapter extends RenderBox {

  RenderBoxToRenderSectorAdapter({ double innerRadius: 0.0, RenderSector child }) :
    _innerRadius = innerRadius {
    _child = child;
    adoptChild(_child);
  }

  double _innerRadius;
  double get innerRadius => _innerRadius;
  void set innerRadius(double value) {
    _innerRadius = value;
    markNeedsLayout();
  }

  RenderSector _child;
  RenderSector get child => _child;
  void set child(RenderSector value) {
    if (_child != null)
      dropChild(_child);
    _child = value;
    adoptChild(_child);
    markNeedsLayout();
  }

  void setupParentData(RenderObject child) {
    if (child.parentData is! SectorParentData)
      child.parentData = new SectorParentData();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return super.getMinIntrinsicWidth(constraints);
    return getIntrinsicDimensions(constraints).width;
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child == null)
      return super.getMaxIntrinsicWidth(constraints);
    return getIntrinsicDimensions(constraints).width;
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return super.getMinIntrinsicHeight(constraints);
    return getIntrinsicDimensions(constraints).height;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child == null)
      return super.getMaxIntrinsicHeight(constraints);
    return getIntrinsicDimensions(constraints).height;
  }

  Size getIntrinsicDimensions(BoxConstraints constraints) {
    assert(child is RenderSector);
    assert(child.parentData is SectorParentData);
    assert(!constraints.isInfinite);
    double maxChildDeltaRadius = math.min(constraints.maxWidth, constraints.maxHeight) / 2.0 - innerRadius;
    SectorDimensions childDimensions = child.getIntrinsicDimensions(new SectorConstraints(maxDeltaRadius: maxChildDeltaRadius), innerRadius);
    double dimension = (innerRadius + childDimensions.deltaRadius) * 2.0;
    return constraints.constrain(new Size(dimension, dimension));
  }

  void performLayout() {
    if (child == null) {
      size = constraints.constrain(Size.zero);
    } else {
      assert(child is RenderSector);
      assert(!constraints.isInfinite);
      double maxChildDeltaRadius = math.min(constraints.maxWidth, constraints.maxHeight) / 2.0 - innerRadius;
      assert(child.parentData is SectorParentData);
      child.parentData.radius = innerRadius;
      child.parentData.theta = 0.0;
      child.layout(new SectorConstraints(maxDeltaRadius: maxChildDeltaRadius), parentUsesSize: true);
      double dimension = (innerRadius + child.deltaRadius) * 2.0;
      size = constraints.constrain(new Size(dimension, dimension));
    }
  }

  void paint(PaintingCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (child != null) {
      Rect bounds = offset & size;
      // we move the offset to the center of the circle for the RenderSectors
      canvas.paintChild(child, bounds.center);
    }
  }

  bool hitTest(HitTestResult result, { Point position }) {
    double x = position.x;
    double y = position.y;
    if (child == null)
      return false;
    // translate to our origin
    x -= size.width/2.0;
    y -= size.height/2.0;
    // convert to radius/theta
    double radius = math.sqrt(x*x+y*y);
    double theta = (math.atan2(x, -y) - math.PI/2.0) % kTwoPi;
    if (radius < innerRadius)
      return false;
    if (radius >= innerRadius + child.deltaRadius)
      return false;
    if (theta > child.deltaTheta)
      return false;
    child.hitTest(result, radius: radius, theta: theta);
    result.add(new BoxHitTestEntry(this, position));
    return true;
  }

}

class RenderSolidColor extends RenderDecoratedSector {
  RenderSolidColor(Color backgroundColor, {
    this.desiredDeltaRadius: double.INFINITY,
    this.desiredDeltaTheta: kTwoPi
  }) : this.backgroundColor = backgroundColor,
       super(new BoxDecoration(backgroundColor: backgroundColor));

  double desiredDeltaRadius;
  double desiredDeltaTheta;
  final Color backgroundColor;

  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    return new SectorDimensions.withConstraints(constraints, deltaTheta: desiredDeltaTheta);
  }

  void performLayout() {
    deltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    deltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
  }

  void handleEvent(sky.Event event, HitTestEntry entry) {
    if (event.type == 'pointerdown')
      decoration = new BoxDecoration(backgroundColor: const Color(0xFFFF0000));
    else if (event.type == 'pointerup')
      decoration = new BoxDecoration(backgroundColor: backgroundColor);
  }
}

RenderBox buildSectorExample() {
  RenderSectorRing rootCircle = new RenderSectorRing(padding: 20.0);
  rootCircle.add(new RenderSolidColor(const Color(0xFF00FFFF), desiredDeltaTheta: kTwoPi * 0.15));
  rootCircle.add(new RenderSolidColor(const Color(0xFF0000FF), desiredDeltaTheta: kTwoPi * 0.4));
  RenderSectorSlice stack = new RenderSectorSlice(padding: 2.0);
  stack.add(new RenderSolidColor(const Color(0xFFFFFF00), desiredDeltaRadius: 20.0));
  stack.add(new RenderSolidColor(const Color(0xFFFF9000), desiredDeltaRadius: 20.0));
  stack.add(new RenderSolidColor(const Color(0xFF00FF00)));
  rootCircle.add(stack);
  return new RenderBoxToRenderSectorAdapter(innerRadius: 50.0, child: rootCircle);
}

void main() {
  new SkyBinding(root: buildSectorExample());
}
