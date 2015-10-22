// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

export 'dart:ui' show Point;

/// Base class for input events.
class InputEvent {

  const InputEvent({ this.type, this.timeStamp: 0.0 });

  final String type;
  // TODO: Should timeStamp be a DateTime object instead of double?
  // Some client code (e.g. drag.dart) does math on the time stamp.
  final double timeStamp;

}

/// Input event representing a touch or button.
class PointerInputEvent extends InputEvent {

  const PointerInputEvent({
    String type,
    double timeStamp: 0.0,
    this.pointer: 0,
    this.kind,
    this.x: 0.0,
    this.y: 0.0,
    this.dx: 0.0,
    this.dy: 0.0,
    this.buttons: 0,
    this.down: false,
    this.primary: false,
    this.obscured: false,
    this.pressure: 0.0,
    this.pressureMin: 0.0,
    this.pressureMax: 0.0,
    this.distance: 0.0,
    this.distanceMin: 0.0,
    this.distanceMax: 0.0,
    this.radiusMajor: 0.0,
    this.radiusMinor: 0.0,
    this.radiusMin: 0.0,
    this.radiusMax: 0.0,
    this.orientation: 0.0,
    this.tilt: 0.0
  }) : super(type: type, timeStamp: timeStamp);

  final int pointer;
  final String kind;
  final double x;
  final double y;
  final double dx;
  final double dy;
  final int buttons;
  final bool down;
  final bool primary;
  final bool obscured;
  final double pressure;
  final double pressureMin;
  final double pressureMax;
  final double distance;
  final double distanceMin;
  final double distanceMax;
  final double radiusMajor;
  final double radiusMinor;
  final double radiusMin;
  final double radiusMax;
  final double orientation;
  final double tilt;

  ui.Point get position => new ui.Point(x, y);
}
