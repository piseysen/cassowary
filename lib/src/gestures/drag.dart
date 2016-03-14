// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'arena.dart';
import 'recognizer.dart';
import 'constants.dart';
import 'events.dart';
import 'velocity_tracker.dart';

enum DragState {
  ready,
  possible,
  accepted
}

typedef void GestureDragStartCallback(Point globalPosition);
typedef void GestureDragUpdateCallback(double delta);
typedef void GestureDragEndCallback(Velocity velocity);

typedef void GesturePanStartCallback(Point globalPosition);
typedef void GesturePanUpdateCallback(Offset delta);
typedef void GesturePanEndCallback(Velocity velocity);

typedef void _GesturePolymorphicUpdateCallback<T>(T delta);

bool _isFlingGesture(Velocity velocity) {
  assert(velocity != null);
  final double speedSquared = velocity.pixelsPerSecond.distanceSquared;
  return speedSquared > kMinFlingVelocity * kMinFlingVelocity
      && speedSquared < kMaxFlingVelocity * kMaxFlingVelocity;
}

abstract class _DragGestureRecognizer<T extends dynamic> extends OneSequenceGestureRecognizer {
  GestureDragStartCallback onStart;
  _GesturePolymorphicUpdateCallback<T> onUpdate;
  GestureDragEndCallback onEnd;

  DragState _state = DragState.ready;
  Point _initialPosition;
  T _pendingDragDelta;

  T get _initialPendingDragDelta;
  T _getDragDelta(PointerEvent event);
  bool get _hasSufficientPendingDragDeltaToAccept;

  Map<int, VelocityTracker> _velocityTrackers = new Map<int, VelocityTracker>();

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
    _velocityTrackers[event.pointer] = new VelocityTracker();
    if (_state == DragState.ready) {
      _state = DragState.possible;
      _initialPosition = event.position;
      _pendingDragDelta = _initialPendingDragDelta;
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != DragState.ready);
    if (event is PointerMoveEvent) {
      VelocityTracker tracker = _velocityTrackers[event.pointer];
      assert(tracker != null);
      tracker.addPosition(event.timeStamp, event.position);
      T delta = _getDragDelta(event);
      if (_state == DragState.accepted) {
        if (onUpdate != null)
          onUpdate(delta);
      } else {
        _pendingDragDelta += delta;
        if (_hasSufficientPendingDragDeltaToAccept)
          resolve(GestureDisposition.accepted);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    if (_state != DragState.accepted) {
      _state = DragState.accepted;
      T delta = _pendingDragDelta;
      _pendingDragDelta = _initialPendingDragDelta;
      if (onStart != null)
        onStart(_initialPosition);
      if (delta != _initialPendingDragDelta && onUpdate != null)
        onUpdate(delta);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (_state == DragState.possible) {
      resolve(GestureDisposition.rejected);
      _state = DragState.ready;
      return;
    }
    bool wasAccepted = (_state == DragState.accepted);
    _state = DragState.ready;
    if (wasAccepted && onEnd != null) {
      VelocityTracker tracker = _velocityTrackers[pointer];
      assert(tracker != null);

      Velocity velocity = tracker.getVelocity();
      if (velocity != null && _isFlingGesture(velocity))
        onEnd(velocity);
      else
        onEnd(Velocity.zero);
    }
    _velocityTrackers.clear();
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }
}

class VerticalDragGestureRecognizer extends _DragGestureRecognizer<double> {
  @override
  double get _initialPendingDragDelta => 0.0;

  @override
  double _getDragDelta(PointerEvent event) => event.delta.dy;

  @override
  bool get _hasSufficientPendingDragDeltaToAccept => _pendingDragDelta.abs() > kTouchSlop;

  @override
  String toStringShort() => 'vertical drag';
}

class HorizontalDragGestureRecognizer extends _DragGestureRecognizer<double> {
  @override
  double get _initialPendingDragDelta => 0.0;

  @override
  double _getDragDelta(PointerEvent event) => event.delta.dx;

  @override
  bool get _hasSufficientPendingDragDeltaToAccept => _pendingDragDelta.abs() > kTouchSlop;

  @override
  String toStringShort() => 'horizontal drag';
}

class PanGestureRecognizer extends _DragGestureRecognizer<Offset> {
  @override
  Offset get _initialPendingDragDelta => Offset.zero;

  @override
  Offset _getDragDelta(PointerEvent event) => event.delta;

  @override
  bool get _hasSufficientPendingDragDeltaToAccept {
    return _pendingDragDelta.distance > kPanSlop;
  }

  @override
  String toStringShort() => 'pan';
}
