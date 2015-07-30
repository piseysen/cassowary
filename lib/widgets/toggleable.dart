// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

import 'package:sky/animation/animated_value.dart';
import 'package:sky/animation/animation_performance.dart';
import 'package:sky/animation/curves.dart';
import 'package:sky/widgets/animated_component.dart';
import 'package:sky/widgets/basic.dart';

export 'package:sky/widgets/basic.dart' show ValueChanged;

const Duration _kCheckDuration = const Duration(milliseconds: 200);

abstract class Toggleable extends AnimatedComponent {

  Toggleable({
    Key key,
    this.value,
    this.onChanged
  }) : super(key: key);

  bool value;
  ValueChanged onChanged;

  AnimatedValue<double> _position;
  AnimatedValue<double> get position => _position;

  AnimationPerformance _performance;
  AnimationPerformance get performance => _performance;

  void initState() {
    _position = new AnimatedValue<double>(0.0, end: 1.0);
    _performance = new AnimationPerformance()
      ..variable = position
      ..duration = _kCheckDuration
      ..progress = value ? 1.0 : 0.0;
    watch(performance);
  }

  void syncFields(Toggleable source) {
    onChanged = source.onChanged;
    if (value != source.value) {
      value = source.value;
      // TODO(abarth): Setting the curve on the position means there's a
      // discontinuity when we reverse the timeline.
      if (value) {
        position.curve = curveUp;
        performance.play();
      } else {
        position.curve = curveDown;
        performance.reverse();
      }
    }
    super.syncFields(source);
  }

  void _handleClick(sky.Event e) {
    onChanged(!value);
  }

  // Override these to draw yourself
  void customPaintCallback(sky.Canvas canvas, Size size);
  Size get size;

  EdgeDims get margin => const EdgeDims.symmetric(horizontal: 5.0);
  double get duration => 200.0;
  Curve get curveUp => easeIn;
  Curve get curveDown => easeOut;

  Widget build() {
    return new Listener(
      child: new Container(
        margin: margin,
        width: size.width,
        height: size.height,
        child: new CustomPaint(
          token: position.value,
          callback: customPaintCallback
        )
      ),
      onGestureTap: _handleClick
    );
  }
}
