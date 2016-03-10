// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'scheduler.dart';

/// Signature for the [onTick] constructor argument of the [Ticker] class.
typedef void TickerCallback(Duration elapsed);

/// Calls its callback once per animation frame.
class Ticker {
  /// Constructs a ticker that will call [onTick] once per frame while running.
  Ticker(TickerCallback onTick) : _onTick = onTick;

  final TickerCallback _onTick;

  Completer<Null> _completer;
  int _animationId;
  Duration _startTime;

  /// Starts calling onTick once per animation frame.
  ///
  /// The returned future resolves once the ticker stops ticking.
  Future<Null> start() {
    assert(!isTicking);
    assert(_startTime == null);
    _completer = new Completer<Null>();
    _scheduleTick();
    return _completer.future;
  }

  /// Stops calling onTick.
  ///
  /// Causes the future returned by [start] to resolve.
  void stop() {
    if (!isTicking)
      return;

    _startTime = null;

    if (_animationId != null) {
      Scheduler.instance.cancelFrameCallbackWithId(_animationId);
      _animationId = null;
    }

    // We take the _completer into a local variable so that isTicking is false
    // when we actually complete the future (isTicking uses _completer
    // to determine its state).
    Completer<Null> localCompleter = _completer;
    _completer = null;
    assert(!isTicking);
    localCompleter.complete();
  }

  /// Whether this ticker has scheduled a call to onTick
  bool get isTicking => _completer != null;

  void _tick(Duration timeStamp) {
    assert(isTicking);
    assert(_animationId != null);
    _animationId = null;

    if (_startTime == null)
      _startTime = timeStamp;

    _onTick(timeStamp - _startTime);

    // The onTick callback may have scheduled another tick already.
    if (isTicking && _animationId == null)
      _scheduleTick();
  }

  void _scheduleTick() {
    assert(isTicking);
    assert(_animationId == null);
    _animationId = Scheduler.instance.scheduleFrameCallback(_tick);
  }
}
