// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vector_math/vector_math.dart';

import 'package:sky/animation/animated_value.dart';
import 'package:sky/animation/animation_performance.dart';
import 'package:sky/painting/box_painter.dart';
import 'package:sky/theme/shadows.dart';
import 'package:sky/widgets/basic.dart';

// This class builds a Container object from a collection of optionally-
// animated properties. Use syncFields to update the Container's properties,
// which will optionally animate them using an AnimationPerformance.
class AnimationBuilder {

  AnimationBuilder();

  AnimatedValue<double> opacity;
  AnimatedValue<Point> position;
  AnimatedValue<double> shadow;
  AnimatedColor backgroundColor;

  // These don't animate, but are used to build the AnimationBuilder anyway.
  double borderRadius;
  Shape shape;

  Map<AnimatedVariable, AnimationPerformance> _variableToPerformance =
      new Map<AnimatedVariable, AnimationPerformance>();

  AnimationPerformance createPerformance(List<AnimatedValue> variables,
                                         { Duration duration }) {
    AnimationPerformance performance = new AnimationPerformance()
      ..duration = duration
      ..variable = new AnimatedList(variables);
    for (AnimatedVariable variable in variables)
      _variableToPerformance[variable] = performance;
    return performance;
  }

  Widget build(Widget child) {
    Widget current = child;
    if (shadow != null || backgroundColor != null ||
        borderRadius != null || shape != null) {
      current = new DecoratedBox(
        decoration: new BoxDecoration(
          borderRadius: borderRadius,
          shape: shape,
          boxShadow: shadow != null ? _computeShadow(shadow.value) : null,
          backgroundColor: backgroundColor != null ? backgroundColor.value : null),
        child: current);
    }

    if (position != null) {
      Matrix4 transform = new Matrix4.identity();
      transform.translate(position.value.x, position.value.y);
      current = new Transform(transform: transform, child: current);
    }

    if (opacity != null) {
      current = new Opacity(opacity: opacity.value, child: current);
    }

    return current;
  }

  void updateFields({
    AnimatedValue<double> shadow,
    AnimatedColor backgroundColor,
    double borderRadius,
    Shape shape
  }) {
    _updateField(this.shadow, shadow);
    _updateField(this.backgroundColor, backgroundColor);
    this.borderRadius = borderRadius;
    this.shape = shape;
  }

  void _updateField(AnimatedValue variable, AnimatedValue sourceVariable) {
    if (variable == null)
      return; // TODO(mpcomplete): Should we handle transition from null?

    AnimationPerformance performance = _variableToPerformance[variable];
    if (performance == null) {
      // If there's no performance, no need to animate.
      if (sourceVariable != null)
        variable.value = sourceVariable.value;
      return;
    }

    if (variable.value != sourceVariable.value) {
      variable
        ..begin = variable.value
        ..end = sourceVariable.value;
      performance
        ..progress = 0.0
        ..play();
    }
  }
}

List<BoxShadow> _computeShadow(double level) {
  if (level < 1.0)  // shadows[1] is the first shadow
    return null;

  int level1 = level.floor();
  int level2 = level.ceil();
  double t = level - level1.toDouble();

  List<BoxShadow> shadow = new List<BoxShadow>();
  for (int i = 0; i < shadows[level1].length; ++i)
    shadow.add(lerpBoxShadow(shadows[level1][i], shadows[level2][i], t));
  return shadow;
}
