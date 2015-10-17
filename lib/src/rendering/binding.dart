// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'box.dart';
import 'hit_test.dart';
import 'object.dart';
import 'view.dart';

int _hammingWeight(int value) {
  if (value == 0)
    return 0;
  int weight = 0;
  for (int i = 0; i < value.bitLength; ++i) {
    if (value & (1 << i) != 0)
      ++weight;
  }
  return weight;
}

typedef void EventListener(InputEvent event);

/// A hit test entry used by [FlutterBinding]
class BindingHitTestEntry extends HitTestEntry {
  const BindingHitTestEntry(HitTestTarget target, this.result) : super(target);

  /// The result of the hit test
  final HitTestResult result;
}

/// State used in converting ui.Event to InputEvent
class _PointerState {
  _PointerState({ this.pointer, this.lastPosition });
  int pointer;
  Point lastPosition;
}

class _UiEventConverter {
  static InputEvent convert(ui.Event event) {
    if (event is ui.PointerEvent)
      return convertPointerEvent(event);

    // Default event
    return new InputEvent(
      type: event.type,
      timeStamp: event.timeStamp
    );
  }

  // Map actual input pointer value to a unique value
  // Since events are serialized we can just use a counter
  static Map<int, _PointerState> _stateForPointer = new Map<int, _PointerState>();
  static int _pointerCount = 0;

  static PointerInputEvent convertPointerEvent(ui.PointerEvent event) {
    Point position = new Point(event.x, event.y);

    _PointerState state = _stateForPointer[event.pointer];
    double dx, dy;
    switch (event.type) {
      case 'pointerdown':
        if (state == null) {
          state = new _PointerState(lastPosition: position);
          _stateForPointer[event.pointer] = state;
        }
        state.pointer = _pointerCount;
        _pointerCount++;
        break;
      case 'pointermove':
        // state == null means the pointer is hovering
        if (state != null) {
          dx = position.x - state.lastPosition.x;
          dy = position.y - state.lastPosition.y;
          state.lastPosition = position;
        }
        break;
      case 'pointerup':
      case 'pointercancel':
        // state == null indicates spurious events
        if (state != null) {
          // Only remove the pointer state when the last button has been released.
          if (_hammingWeight(event.buttons) <= 1)
            _stateForPointer.remove(event.pointer);
        }
        break;
    }

    return new PointerInputEvent(
       type: event.type,
       timeStamp: event.timeStamp,
       pointer: state.pointer,
       kind: event.kind,
       x: event.x,
       y: event.y,
       dx: dx,
       dy: dy,
       buttons: event.buttons,
       down: event.down,
       primary: event.primary,
       obscured: event.obscured,
       pressure: event.pressure,
       pressureMin: event.pressureMin,
       pressureMax: event.pressureMax,
       distance: event.distance,
       distanceMin: event.distanceMin,
       distanceMax: event.distanceMax,
       radiusMajor: event.radiusMajor,
       radiusMinor: event.radiusMinor,
       radiusMin: event.radiusMin,
       radiusMax: event.radiusMax,
       orientation: event.orientation,
       tilt: event.tilt
     );
  }

}

/// The glue between the render tree and the Flutter engine
class FlutterBinding extends HitTestTarget {

  FlutterBinding({ RenderBox root: null, RenderView renderViewOverride }) {
    assert(_instance == null);
    _instance = this;

    ui.view.setEventCallback(_handleEvent);

    ui.view.setMetricsChangedCallback(_handleMetricsChanged);
    if (renderViewOverride == null) {
      _renderView = new RenderView(child: root);
      _renderView.attach();
      _renderView.rootConstraints = _createConstraints();
      _renderView.scheduleInitialFrame();
    } else {
      _renderView = renderViewOverride;
    }
    assert(_renderView != null);
    scheduler.addPersistentFrameCallback(beginFrame);

    assert(_instance == this);
  }

  /// The singleton instance of the binding
  static FlutterBinding get instance => _instance;
  static FlutterBinding _instance;

  /// The render tree that's attached to the output surface
  RenderView get renderView => _renderView;
  RenderView _renderView;

  ViewConstraints _createConstraints() {
    return new ViewConstraints(size: new Size(ui.view.width, ui.view.height));
  }
  void _handleMetricsChanged() {
    _renderView.rootConstraints = _createConstraints();
  }

  /// Pump the rendering pipeline to generate a frame for the given time stamp
  void beginFrame(Duration timeStamp) {
    RenderObject.flushLayout();
    _renderView.updateCompositingBits();
    RenderObject.flushPaint();
    _renderView.compositeFrame();
  }

  final List<EventListener> _eventListeners = new List<EventListener>();

  /// Calls listener for every event that isn't localized to a given view coordinate
  void addEventListener(EventListener listener) => _eventListeners.add(listener);

  /// Stops calling listener for every event that isn't localized to a given view coordinate
  bool removeEventListener(EventListener listener) => _eventListeners.remove(listener);

  void _handleEvent(ui.Event event) {
    InputEvent ourEvent = _UiEventConverter.convert(event);
    if (ourEvent is PointerInputEvent) {
      _handlePointerInputEvent(ourEvent);
    } else {
      for (EventListener listener in _eventListeners)
        listener(ourEvent);
    }
  }

  /// A router that routes all pointer events received from the engine
  final PointerRouter pointerRouter = new PointerRouter();

  /// State for all pointers which are currently down.
  /// We do not track the state of hovering pointers because we need
  /// to hit-test them on each movement.
  Map<int, HitTestResult> _resultForPointer = new Map<int, HitTestResult>();

  void _handlePointerInputEvent(PointerInputEvent event) {
    HitTestResult result = _resultForPointer[event.pointer];
    switch (event.type) {
      case 'pointerdown':
        if (result == null) {
          result = hitTest(new Point(event.x, event.y));
          _resultForPointer[event.pointer] = result;
        }
        break;
      case 'pointermove':
        if (result == null) {
          // The pointer is hovering, ignore it for now since we don't
          // know what to do with it yet.
          return;
        }
        break;
      case 'pointerup':
      case 'pointercancel':
        if (result == null) {
          // This seems to be a spurious event.  Ignore it.
          return;
        }
        // Only remove the hit test result when the last button has been released.
        if (_hammingWeight(event.buttons) <= 1)
          _resultForPointer.remove(event.pointer);
        break;
    }
    dispatchEvent(event, result);
  }

  /// Determine which [HitTestTarget] objects are located at a given position
  HitTestResult hitTest(Point position) {
    HitTestResult result = new HitTestResult();
    _renderView.hitTest(result, position: position);
    result.add(new BindingHitTestEntry(this, result));
    return result;
  }

  /// Dispatch the given event to the path of the given hit test result
  void dispatchEvent(InputEvent event, HitTestResult result) {
    assert(result != null);
    for (HitTestEntry entry in result.path)
      entry.target.handleEvent(event, entry);
  }

  void handleEvent(InputEvent e, BindingHitTestEntry entry) {
    if (e is PointerInputEvent) {
      PointerInputEvent event = e;
      pointerRouter.route(event);
      if (event.type == 'pointerdown')
        GestureArena.instance.close(event.pointer);
      else if (event.type == 'pointerup')
        GestureArena.instance.sweep(event.pointer);
    }
  }
}

/// Prints a textual representation of the entire render tree
void debugDumpRenderTree() {
  debugPrint(FlutterBinding.instance.renderView.toStringDeep());
}
