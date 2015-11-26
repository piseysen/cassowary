// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'constants.dart';

const Duration _kToggleDuration = const Duration(milliseconds: 200);

// RenderToggleable is a base class for material style toggleable controls with
// toggle animations. It handles storing the current value, dispatching
// ValueChanged on a tap gesture and driving a changed animation. Subclasses are
// responsible for painting.
abstract class RenderToggleable extends RenderConstrainedBox {
  RenderToggleable({
    bool value,
    Size size,
    Color accentColor,
    this.onChanged,
    double minRadialReactionRadius: 0.0
  }) : _value = value,
       _accentColor = accentColor,
       super(additionalConstraints: new BoxConstraints.tight(size)) {
    _tap = new TapGestureRecognizer(router: FlutterBinding.instance.pointerRouter)
      ..onTapDown = _handleTapDown
      ..onTap = _handleTap
      ..onTapUp = _handleTapUp
      ..onTapCancel = _handleTapCancel;
    _position = new ValuePerformance<double>(
      variable: new AnimatedValue<double>(0.0, end: 1.0),
      duration: _kToggleDuration,
      progress: _value ? 1.0 : 0.0
    )..addListener(markNeedsPaint)
     ..addStatusListener(_handlePositionStateChanged);
    _reaction = new ValuePerformance<double>(
      variable: new AnimatedValue<double>(minRadialReactionRadius, end: kRadialReactionRadius, curve: Curves.ease),
      duration: kRadialReactionDuration
    )..addListener(markNeedsPaint);
  }

  bool get value => _value;
  bool _value;
  void set value(bool value) {
    if (value == _value)
      return;
    _value = value;
    _position.variable
      ..curve = Curves.easeIn
      ..reverseCurve = Curves.easeOut;
    _position.play(value ? AnimationDirection.forward : AnimationDirection.reverse);
  }

  Color get accentColor => _accentColor;
  Color _accentColor;
  void set accentColor(Color value) {
    if (value == _accentColor)
      return;
    _accentColor = value;
    markNeedsPaint();
  }

  bool get isInteractive => onChanged != null;

  ValueChanged<bool> onChanged;

  ValuePerformance<double> get position => _position;
  ValuePerformance<double> _position;

  ValuePerformance<double> get reaction => _reaction;
  ValuePerformance<double> _reaction;

  TapGestureRecognizer _tap;

  void _handlePositionStateChanged(PerformanceStatus status) {
    if (isInteractive) {
      if (status == PerformanceStatus.completed && !_value)
        onChanged(true);
      else if (status == PerformanceStatus.dismissed && _value)
        onChanged(false);
    }
  }

  void _handleTapDown(Point globalPosition) {
    if (isInteractive)
      _reaction.forward();
  }

  void _handleTap() {
    if (isInteractive)
      onChanged(!_value);
  }

  void _handleTapUp(Point globalPosition) {
    if (isInteractive)
      _reaction.reverse();
  }

  void _handleTapCancel() {
    if (isInteractive)
      _reaction.reverse();
  }

  bool hitTestSelf(Point position) => true;

  void handleEvent(InputEvent event, BoxHitTestEntry entry) {
    if (event.type == 'pointerdown' && isInteractive)
      _tap.addPointer(event);
  }

  void paintRadialReaction(Canvas canvas, Offset offset) {
    if (!reaction.isDismissed) {
      Paint reactionPaint = new Paint()..color = accentColor.withAlpha(kRadialReactionAlpha);
      canvas.drawCircle(offset.toPoint(), reaction.value, reactionPaint);
    }
  }
}
