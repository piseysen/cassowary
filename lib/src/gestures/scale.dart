// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'arena.dart';
import 'recognizer.dart';
import 'constants.dart';
import 'events.dart';

enum ScaleState {
  ready,
  possible,
  accepted,
  started
}

typedef void GestureScaleStartCallback(ui.Point focalPoint);
typedef void GestureScaleUpdateCallback(double scale, ui.Point focalPoint);
typedef void GestureScaleEndCallback();

class ScaleGestureRecognizer extends GestureRecognizer {
  ScaleGestureRecognizer({ PointerRouter router, this.onStart, this.onUpdate, this.onEnd })
    : super(router: router);

  GestureScaleStartCallback onStart;
  GestureScaleUpdateCallback onUpdate;
  GestureScaleEndCallback onEnd;

  ScaleState _state = ScaleState.ready;

  double _initialSpan;
  double _currentSpan;
  Map<int, ui.Point> _pointerLocations;

  double get _scaleFactor => _initialSpan > 0.0 ? _currentSpan / _initialSpan : 1.0;

  void addPointer(PointerInputEvent event) {
    startTrackingPointer(event.pointer);
    if (_state == ScaleState.ready) {
      _state = ScaleState.possible;
      _initialSpan = 0.0;
      _currentSpan = 0.0;
      _pointerLocations = new Map<int, ui.Point>();
    }
  }

  void handleEvent(PointerInputEvent event) {
    assert(_state != ScaleState.ready);
    bool configChanged = false;
    switch(event.type) {
      case 'pointerup':
        configChanged = true;
        _pointerLocations.remove(event.pointer);
        break;
      case 'pointerdown':
        configChanged = true;
        _pointerLocations[event.pointer] = new ui.Point(event.x, event.y);
        break;
      case 'pointermove':
        _pointerLocations[event.pointer] = new ui.Point(event.x, event.y);
        break;
    }

    _update(configChanged);

    stopTrackingIfPointerNoLongerDown(event);
  }

  void _update(bool configChanged) {
    int count = _pointerLocations.keys.length;

    // Compute the focal point
    ui.Point focalPoint = ui.Point.origin;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer].toOffset();
    focalPoint = new ui.Point(focalPoint.x / count, focalPoint.y / count);

    // Span is the average deviation from focal point
    double totalDeviation = 0.0;
    for (int pointer in _pointerLocations.keys)
      totalDeviation += (focalPoint - _pointerLocations[pointer]).distance;
    _currentSpan = count > 0 ? totalDeviation / count : 0.0;

    if (configChanged) {
      _initialSpan = _currentSpan;
      if (_state == ScaleState.started) {
        if (onEnd != null)
          onEnd();
        _state = ScaleState.accepted;
      }
    }

    if (_state == ScaleState.ready)
      _state = ScaleState.possible;

    if (_state == ScaleState.possible &&
        (_currentSpan - _initialSpan).abs() > kScaleSlop) {
      resolve(GestureDisposition.accepted);
    }

    if (_state == ScaleState.accepted && !configChanged) {
      _state = ScaleState.started;
      if (onStart != null)
        onStart(focalPoint);
    }

    if (_state == ScaleState.started && onUpdate != null)
      onUpdate(_scaleFactor, focalPoint);
  }

  void acceptGesture(int pointer) {
    if (_state != ScaleState.accepted) {
      _state = ScaleState.accepted;
      _update(false);
    }
  }

  void didStopTrackingLastPointer(int pointer) {
    switch(_state) {
      case ScaleState.possible:
        resolve(GestureDisposition.rejected);
        break;
      case ScaleState.ready:
        assert(false);  // We should have not seen a pointer yet
        break;
      case ScaleState.accepted:
        break;
      case ScaleState.started:
        assert(false);  // We should be in the accepted state when user is done
        break;
    }
    _state = ScaleState.ready;
  }
}
