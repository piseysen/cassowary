// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:sky/src/animation/animated_value.dart';
import 'package:sky/src/animation/forces.dart';
import 'package:sky/src/animation/timeline.dart';

enum AnimationStatus {
  dismissed, // stoped at 0
  forward,   // animating from 0 => 1
  reverse,   // animating from 1 => 0
  completed, // stopped at 1
}

// This class manages a "performance" - a collection of values that change
// based on a timeline. For example, a performance may handle an animation
// of a menu opening by sliding and fading in (changing Y value and opacity)
// over .5 seconds. The performance can move forwards (present) or backwards
// (dismiss). A consumer may also take direct control of the timeline by
// manipulating |progress|, or |fling| the timeline causing a physics-based
// simulation to take over the progression.
class AnimationPerformance {
  AnimationPerformance({AnimatedVariable variable, this.duration}) :
    _variable = variable {
    _timeline = new Timeline(_tick);
  }

  AnimatedVariable _variable;
  Duration duration;

  AnimatedVariable get variable => _variable;
  void set variable(AnimatedVariable v) { _variable = v; }

  // Advances from 0 to 1. On each tick, we'll update our variable's values.
  Timeline _timeline;
  Timeline get timeline => _timeline;

  Direction _direction;
  Direction get direction => _direction;

  // This controls which curve we use for variables with different curves in
  // the forward/reverse directions. Curve direction is only reset when we hit
  // 0 or 1, to avoid discontinuities.
  Direction _curveDirection;
  Direction get curveDirection => _curveDirection;

  AnimationTiming timing;

  // If non-null, animate with this force instead of a tween animation.
  Force attachedForce;

  void addVariable(AnimatedVariable newVariable) {
    if (variable == null) {
      variable = newVariable;
    } else if (variable is AnimatedList) {
      (variable as AnimatedList).variables.add(newVariable);
    } else {
      variable = new AnimatedList([variable, newVariable]);
    }
  }

  double get progress => timeline.value;
  void set progress(double t) {
    // TODO(mpcomplete): should this affect |direction|?
    stop();
    timeline.value = t.clamp(0.0, 1.0);
    _checkStatusChanged();
  }

  double get curvedProgress {
    return timing != null ? timing.transform(progress, curveDirection) : progress;
  }

  bool get isDismissed => status == AnimationStatus.dismissed;
  bool get isCompleted => status == AnimationStatus.completed;
  bool get isAnimating => timeline.isAnimating;

  AnimationStatus get status {
    if (!isAnimating && progress == 1.0)
      return AnimationStatus.completed;
    if (!isAnimating && progress == 0.0)
      return AnimationStatus.dismissed;
    return direction == Direction.forward ?
        AnimationStatus.forward :
        AnimationStatus.reverse;
  }

  void updateVariable(AnimatedVariable variable) {
    variable.setProgress(curvedProgress, curveDirection);
  }

  Future play([Direction direction = Direction.forward]) {
    _direction = direction;
    return resume();
  }
  Future forward() => play(Direction.forward);
  Future reverse() => play(Direction.reverse);
  Future resume() {
    if (attachedForce != null) {
      return fling(velocity: _direction == Direction.forward ? 1.0 : -1.0,
                   force: attachedForce);
    }
    return _animateTo(direction == Direction.forward ? 1.0 : 0.0);
  }

  void stop() {
    timeline.stop();
  }

  // Flings the timeline with an optional force (defaults to a critically
  // damped spring) and initial velocity. If velocity is positive, the
  // animation will complete, otherwise it will dismiss.
  Future fling({double velocity: 1.0, Force force}) {
    if (force == null)
      force = kDefaultSpringForce;
    _direction = velocity < 0.0 ? Direction.reverse : Direction.forward;
    return timeline.fling(force.release(progress, velocity));
  }

  final List<Function> _listeners = new List<Function>();

  void addListener(Function listener) {
    _listeners.add(listener);
  }

  void removeListener(Function listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    List<Function> localListeners = new List<Function>.from(_listeners);
    for (Function listener in localListeners)
      listener();
  }

  final List<Function> _statusListeners = new List<Function>();

  void addStatusListener(Function listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(Function listener) {
    _statusListeners.remove(listener);
  }

  AnimationStatus _lastStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    AnimationStatus currentStatus = status;
    if (currentStatus != _lastStatus) {
      List<Function> localListeners = new List<Function>.from(_statusListeners);
      for (Function listener in localListeners)
        listener(currentStatus);
    }
    _lastStatus = currentStatus;
  }

  void _updateCurveDirection() {
    if (status != _lastStatus) {
      if (_lastStatus == AnimationStatus.dismissed || _lastStatus == AnimationStatus.completed)
        _curveDirection = direction;
    }
  }

  Future _animateTo(double target) {
    Duration remainingDuration = duration * (target - timeline.value).abs();
    timeline.stop();
    if (remainingDuration == Duration.ZERO)
      return new Future.value();
    return timeline.animateTo(target, duration: remainingDuration);
  }

  void _tick(double t) {
    _updateCurveDirection();
    if (variable != null)
      variable.setProgress(curvedProgress, curveDirection);
    _notifyListeners();
    _checkStatusChanged();
  }
}

// Simple helper class for an animation with a single value.
class ValueAnimation<T> extends AnimationPerformance {
  ValueAnimation({AnimatedValue<T> variable, Duration duration}) :
    super(variable: variable, duration: duration);

  AnimatedValue<T> get variable => _variable as AnimatedValue<T>;
  void set variable(AnimatedValue<T> v) { _variable = v; }

  T get value => variable.value;
}
