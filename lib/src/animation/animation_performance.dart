// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:sky/src/animation/animated_value.dart';
import 'package:sky/src/animation/forces.dart';
import 'package:sky/src/animation/timeline.dart';

/// The status of an animation
enum AnimationStatus {
  /// The animation is stopped at the beginning
  dismissed,

  /// The animation is running from beginning to end
  forward,

  /// The animation is running backwards, from end to beginning
  reverse,

  /// The animation is stopped at the end
  completed,
}

typedef void AnimationPerformanceListener();
typedef void AnimationPerformanceStatusListener(AnimationStatus status);

/// An interface that is implemented by [AnimationPerformance] that exposes a
/// read-only view of the underlying performance. This is used by classes that
/// want to watch a performance but should not be able to change the
/// performance's state.
abstract class WatchableAnimationPerformance {
  /// Update the given variable according to the current progress of the performance
  void updateVariable(AnimatedVariable variable);
  /// Calls the listener every time the progress of the performance changes
  void addListener(AnimationPerformanceListener listener);
  /// Stop calling the listener every time the progress of the performance changes
  void removeListener(AnimationPerformanceListener listener);
  /// Calls listener every time the status of the performance changes
  void addStatusListener(AnimationPerformanceStatusListener listener);
  /// Stops calling the listener every time the status of the performance changes
  void removeStatusListener(AnimationPerformanceStatusListener listener);
}

/// A timeline that can be reversed and used to update [AnimatedVariable]s.
///
/// For example, a performance may handle an animation of a menu opening by
/// sliding and fading in (changing Y value and opacity) over .5 seconds. The
/// performance can move forwards (present) or backwards (dismiss). A consumer
/// may also take direct control of the timeline by manipulating [progress], or
/// [fling] the timeline causing a physics-based simulation to take over the
/// progression.
class AnimationPerformance implements WatchableAnimationPerformance {
  AnimationPerformance({ this.duration, double progress }) {
    _timeline = new Timeline(_tick);
    if (progress != null)
      _timeline.value = progress.clamp(0.0, 1.0);
  }

  /// Returns a [WatchableAnimationPerformance] for this performance,
  /// so that a pointer to this object can be passed around without
  /// allowing users of that pointer to mutate the AnimationPerformance state.
  WatchableAnimationPerformance get view => this;

  /// The length of time this performance should last
  Duration duration;

  Timeline _timeline;
  Direction _direction;

  /// The direction used to select the current curve
  ///
  /// Curve direction is only reset when we hit the beginning or the end of the
  /// timeline to avoid discontinuities in the value of any variables this
  /// performance is used to animate.
  Direction _curveDirection;

  /// If non-null, animate with this timing instead of a linear timing
  AnimationTiming timing;

  /// The progress of this performance along the timeline
  ///
  /// Note: Setting this value stops the current animation.
  double get progress => _timeline.value.clamp(0.0, 1.0);
  void set progress(double t) {
    // TODO(mpcomplete): should this affect |direction|?
    stop();
    _timeline.value = t.clamp(0.0, 1.0);
    _checkStatusChanged();
  }

  double get _curvedProgress {
    return timing != null ? timing.transform(progress, _curveDirection) : progress;
  }

  /// Whether this animation is stopped at the beginning
  bool get isDismissed => status == AnimationStatus.dismissed;

  /// Whether this animation is stopped at the end
  bool get isCompleted => status == AnimationStatus.completed;

  /// Whether this animation is currently animating in either the forward or reverse direction
  bool get isAnimating => _timeline.isAnimating;

  /// The current status of this animation
  AnimationStatus get status {
    if (!isAnimating && progress == 1.0)
      return AnimationStatus.completed;
    if (!isAnimating && progress == 0.0)
      return AnimationStatus.dismissed;
    return _direction == Direction.forward ?
        AnimationStatus.forward :
        AnimationStatus.reverse;
  }

  /// Update the given varaible according to the current progress of this performance
  void updateVariable(AnimatedVariable variable) {
    variable.setProgress(_curvedProgress, _curveDirection);
  }

  /// Start running this animation forwards (towards the end)
  Future forward() => play(Direction.forward);

  /// Start running this animation in reverse (towards the beginning)
  Future reverse() => play(Direction.reverse);

  /// Start running this animation in the given direction
  Future play([Direction direction = Direction.forward]) {
    _direction = direction;
    return resume();
  }

  /// Start running this animation in the most recently direction
  Future resume() {
    return _animateTo(_direction == Direction.forward ? 1.0 : 0.0);
  }

  /// Stop running this animation
  void stop() {
    _timeline.stop();
  }

  /// Start running this animation according to the given physical parameters
  ///
  /// Flings the timeline with an optional force (defaults to a critically
  /// damped spring) and initial velocity. If velocity is positive, the
  /// animation will complete, otherwise it will dismiss.
  Future fling({double velocity: 1.0, Force force}) {
    if (force == null)
      force = kDefaultSpringForce;
    _direction = velocity < 0.0 ? Direction.reverse : Direction.forward;
    return _timeline.fling(force.release(progress, velocity));
  }

  final List<AnimationPerformanceListener> _listeners = new List<AnimationPerformanceListener>();

  /// Calls the listener every time the progress of this performance changes
  void addListener(AnimationPerformanceListener listener) {
    _listeners.add(listener);
  }

  /// Stop calling the listener every time the progress of this performance changes
  void removeListener(AnimationPerformanceListener listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    List<AnimationPerformanceListener> localListeners = new List<AnimationPerformanceListener>.from(_listeners);
    for (AnimationPerformanceListener listener in localListeners)
      listener();
  }

  final List<AnimationPerformanceStatusListener> _statusListeners = new List<AnimationPerformanceStatusListener>();

  /// Calls listener every time the status of this performance changes
  void addStatusListener(AnimationPerformanceStatusListener listener) {
    _statusListeners.add(listener);
  }

  /// Stops calling the listener every time the status of this performance changes
  void removeStatusListener(AnimationPerformanceStatusListener listener) {
    _statusListeners.remove(listener);
  }

  AnimationStatus _lastStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    AnimationStatus currentStatus = status;
    if (currentStatus != _lastStatus) {
      List<AnimationPerformanceStatusListener> localListeners = new List<AnimationPerformanceStatusListener>.from(_statusListeners);
      for (AnimationPerformanceStatusListener listener in localListeners)
        listener(currentStatus);
    }
    _lastStatus = currentStatus;
  }

  void _updateCurveDirection() {
    if (status != _lastStatus) {
      if (_lastStatus == AnimationStatus.dismissed || _lastStatus == AnimationStatus.completed)
        _curveDirection = _direction;
    }
  }

  Future _animateTo(double target) {
    Duration remainingDuration = duration * (target - _timeline.value).abs();
    _timeline.stop();
    if (remainingDuration == Duration.ZERO)
      return new Future.value();
    return _timeline.animateTo(target, duration: remainingDuration);
  }

  void _tick(double t) {
    _updateCurveDirection();
    didTick(t);
  }

  void didTick(double t) {
    _notifyListeners();
    _checkStatusChanged();
  }
}

/// An animation performance with an animated variable with a concrete type
class ValueAnimation<T> extends AnimationPerformance {
  ValueAnimation({ this.variable, Duration duration, double progress }) :
    super(duration: duration, progress: progress);

  AnimatedValue<T> variable;
  T get value => variable.value;

  void didTick(double t) {
    if (variable != null)
      variable.setProgress(_curvedProgress, _curveDirection);
    super.didTick(t);
  }
}
