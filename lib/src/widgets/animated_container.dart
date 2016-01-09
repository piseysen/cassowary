// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';

import 'basic.dart';
import 'framework.dart';

import 'package:vector_math/vector_math_64.dart';

/// An animated value that interpolates [BoxConstraint]s.
class AnimatedBoxConstraintsValue extends AnimatedValue<BoxConstraints> {
  AnimatedBoxConstraintsValue(BoxConstraints begin, { BoxConstraints end, Curve curve, Curve reverseCurve })
    : super(begin, end: end, curve: curve, reverseCurve: reverseCurve);

  BoxConstraints lerp(double t) => BoxConstraints.lerp(begin, end, t);
}

/// An animated value that interpolates [Decoration]s.
class AnimatedDecorationValue extends AnimatedValue<Decoration> {
  AnimatedDecorationValue(Decoration begin, { Decoration end, Curve curve, Curve reverseCurve })
    : super(begin, end: end, curve: curve, reverseCurve: reverseCurve);

  Decoration lerp(double t) {
    if (begin == null && end == null)
      return null;
    if (end == null)
      return begin.lerpTo(end, t);
    return end.lerpFrom(begin, t);
  }
}

/// An animated value that interpolates [EdgeDims].
class AnimatedEdgeDimsValue extends AnimatedValue<EdgeDims> {
  AnimatedEdgeDimsValue(EdgeDims begin, { EdgeDims end, Curve curve, Curve reverseCurve })
    : super(begin, end: end, curve: curve, reverseCurve: reverseCurve);

  EdgeDims lerp(double t) => EdgeDims.lerp(begin, end, t);
}

/// An animated value that interpolates [Matrix4]s.
///
/// Currently this class works only for translations.
class AnimatedMatrix4Value extends AnimatedValue<Matrix4> {
  AnimatedMatrix4Value(Matrix4 begin, { Matrix4 end, Curve curve, Curve reverseCurve })
    : super(begin, end: end, curve: curve, reverseCurve: reverseCurve);

  Matrix4 lerp(double t) {
    // TODO(mpcomplete): Animate the full matrix. Will animating the cells
    // separately work?
    Vector3 beginT = begin.getTranslation();
    Vector3 endT = end.getTranslation();
    Vector3 lerpT = beginT*(1.0-t) + endT*t;
    return new Matrix4.identity()..translate(lerpT);
  }
}

/// A container that gradually changes its values over a period of time.
///
/// This class is useful for generating simple implicit transitions between
/// different parameters to [Container]. For more complex animations, you'll
/// likely want to use a subclass of [Transition] or control a [Performance]
/// yourself.
class AnimatedContainer extends StatefulComponent {
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
    this.curve: Curves.linear,
    this.duration
  }) : super(key: key) {
    assert(margin == null || margin.isNonNegative);
    assert(padding == null || padding.isNonNegative);
    assert(decoration == null || decoration.debugAssertValid());
    assert(foregroundDecoration == null || foregroundDecoration.debugAssertValid());
    assert(curve != null);
    assert(duration != null);
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

  /// The curve to apply when animating the parameters of this container.
  final Curve curve;

  /// The duration over which to animate the parameters of this container.
  final Duration duration;

  _AnimatedContainerState createState() => new _AnimatedContainerState();
}

class _AnimatedContainerState extends State<AnimatedContainer> {
  AnimatedBoxConstraintsValue _constraints;
  AnimatedDecorationValue _decoration;
  AnimatedDecorationValue _foregroundDecoration;
  AnimatedEdgeDimsValue _margin;
  AnimatedEdgeDimsValue _padding;
  AnimatedMatrix4Value _transform;
  AnimatedValue<double> _width;
  AnimatedValue<double> _height;

  Performance _performanceController;
  PerformanceView _performance;

  void initState() {
    super.initState();
    _performanceController = new Performance(
      duration: config.duration,
      debugLabel: '${config.toStringShort()}'
    );
    _updateCurve();
    _configAllVariables();
  }

  void didUpdateConfig(AnimatedContainer oldConfig) {
    if (config.curve != oldConfig.curve)
      _updateCurve();
    _performanceController.duration = config.duration;
    if (_configAllVariables()) {
      _updateBeginValue(_constraints);
      _updateBeginValue(_decoration);
      _updateBeginValue(_foregroundDecoration);
      _updateBeginValue(_margin);
      _updateBeginValue(_padding);
      _updateBeginValue(_transform);
      _updateBeginValue(_width);
      _updateBeginValue(_height);
      _performanceController.progress = 0.0;
      _performanceController.play();
    }
  }

  void _updateCurve() {
    _performance?.removeListener(_updateAllVariables);
    if (config.curve != null)
      _performance = new CurvedPerformance(_performanceController, curve: config.curve);
    else
      _performance = _performanceController;
    _performance.addListener(_updateAllVariables);
  }

  void dispose() {
    _performanceController.stop();
    super.dispose();
  }

  void _updateVariable(Animatable variable) {
    if (variable != null)
      _performance.updateVariable(variable);
  }

  void _updateAllVariables() {
    setState(() {
      _updateVariable(_constraints);
      _updateVariable(_decoration);
      _updateVariable(_foregroundDecoration);
      _updateVariable(_margin);
      _updateVariable(_padding);
      _updateVariable(_transform);
      _updateVariable(_width);
      _updateVariable(_height);
    });
  }

  bool _updateEndValue(AnimatedValue variable, dynamic targetValue) {
    if (targetValue == variable.end)
      return false;
    variable.end = targetValue;
    return true;
  }

  void _updateBeginValue(AnimatedValue variable) {
    variable?.begin = variable.value;
  }

  bool _configAllVariables() {
    bool startAnimation = false;
    if (config.constraints != null) {
      _constraints ??= new AnimatedBoxConstraintsValue(config.constraints);
      if (_updateEndValue(_constraints, config.constraints))
        startAnimation = true;
    } else {
      _constraints = null;
    }

    if (config.decoration != null) {
      _decoration ??= new AnimatedDecorationValue(config.decoration);
      if (_updateEndValue(_decoration, config.decoration))
        startAnimation = true;
    } else {
      _decoration = null;
    }

    if (config.foregroundDecoration != null) {
      _foregroundDecoration ??= new AnimatedDecorationValue(config.foregroundDecoration);
      if (_updateEndValue(_foregroundDecoration, config.foregroundDecoration))
        startAnimation = true;
    } else {
      _foregroundDecoration = null;
    }

    if (config.margin != null) {
      _margin ??= new AnimatedEdgeDimsValue(config.margin);
      if (_updateEndValue(_margin, config.margin))
        startAnimation = true;
    } else {
      _margin = null;
    }

    if (config.padding != null) {
      _padding ??= new AnimatedEdgeDimsValue(config.padding);
      if (_updateEndValue(_padding, config.padding))
        startAnimation = true;
    } else {
      _padding = null;
    }

    if (config.transform != null) {
      _transform ??= new AnimatedMatrix4Value(config.transform);
      if (_updateEndValue(_transform, config.transform))
        startAnimation = true;
    } else {
      _transform = null;
    }

    if (config.width != null) {
      _width ??= new AnimatedValue<double>(config.width);
      if (_updateEndValue(_width, config.width))
        startAnimation = true;
    } else {
      _width = null;
    }

    if (config.height != null) {
      _height ??= new AnimatedValue<double>(config.height);
      if (_updateEndValue(_height, config.height))
        startAnimation = true;
    } else {
      _height = null;
    }

    return startAnimation;
  }

  Widget build(BuildContext context) {
    return new Container(
      child: config.child,
      constraints: _constraints?.value,
      decoration: _decoration?.value,
      foregroundDecoration: _foregroundDecoration?.value,
      margin: _margin?.value,
      padding: _padding?.value,
      transform: _transform?.value,
      width: _width?.value,
      height: _height?.value
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
