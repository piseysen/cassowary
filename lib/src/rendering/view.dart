// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as sky;

import 'package:sky/animation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'box.dart';
import 'layer.dart';
import 'object.dart';

/// The layout constraints for the root render object
class ViewConstraints {
  const ViewConstraints({
    this.size: Size.zero,
    this.orientation
  });

  /// The size of the output surface
  final Size size;

  /// The orientation of the output surface (aspirational)
  final int orientation;
}

/// The root of the render tree
///
/// The view represents the total output surface of the render tree and handles
/// bootstraping the rendering pipeline. The view has a unique child
/// [RenderBox], which is required to fill the entire output surface.
class RenderView extends RenderObject with RenderObjectWithChildMixin<RenderBox> {
  RenderView({
    RenderBox child,
    this.timeForRotation: const Duration(microseconds: 83333)
  }) {
    this.child = child;
  }

  /// The amount of time the screen rotation animation should last (aspirational)
  Duration timeForRotation;

  /// The current layout size of the view
  Size get size => _size;
  Size _size = Size.zero;

  /// The current orientation of the view (aspirational)
  int get orientation => _orientation;
  int _orientation; // 0..3

  /// The constraints used for the root layout
  ViewConstraints get rootConstraints => _rootConstraints;
  ViewConstraints _rootConstraints;
  void set rootConstraints(ViewConstraints value) {
    if (_rootConstraints == value)
      return;
    _rootConstraints = value;
    markNeedsLayout();
  }

  Matrix4 get _logicalToDeviceTransform {
    double devicePixelRatio = sky.view.devicePixelRatio;
    return new Matrix4.diagonal3Values(devicePixelRatio, devicePixelRatio, 1.0);
  }

  /// Bootstrap the rendering pipeline by scheduling the first frame
  void scheduleInitialFrame() {
    scheduleInitialLayout();
    scheduleInitialPaint(new TransformLayer(transform: _logicalToDeviceTransform));
    scheduler.ensureVisualUpdate();
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
    if (child != null)
      child.hitTest(result, position: position);
    result.add(new HitTestEntry(this));
    return true;
  }

  bool get hasLayer => true;

  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child, offset.toPoint());
  }

  /// Uploads the composited layer tree to the engine
  ///
  /// Actually causes the output of the rendering pipeline to appear on screen.
  void compositeFrame() {
    sky.tracing.begin('RenderView.compositeFrame');
    try {
      (layer as TransformLayer).transform = _logicalToDeviceTransform;
      Rect bounds = Point.origin & (size * sky.view.devicePixelRatio);
      sky.SceneBuilder builder = new sky.SceneBuilder(bounds);
      layer.addToScene(builder, Offset.zero);
      sky.view.scene = builder.build();
    } finally {
      sky.tracing.end('RenderView.compositeFrame');
    }
  }

  Rect get paintBounds => Point.origin & size;
}
