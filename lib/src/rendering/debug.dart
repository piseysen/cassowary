// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;
import 'dart:async';
import 'dart:collection';

/// Causes each RenderBox to paint a box around its bounds.
bool debugPaintSizeEnabled = false;

/// The color to use when painting RenderObject bounds.
ui.Color debugPaintSizeColor = const ui.Color(0xFF00FFFF);

/// Causes each RenderBox to paint a line at each of its baselines.
bool debugPaintBaselinesEnabled = false;

/// The color to use when painting alphabetic baselines.
ui.Color debugPaintAlphabeticBaselineColor = const ui.Color(0xFF00FF00);

/// The color ot use when painting ideographic baselines.
ui.Color debugPaintIdeographicBaselineColor = const ui.Color(0xFFFFD000);

/// Causes each Layer to paint a box around its bounds.
bool debugPaintLayerBordersEnabled = false;

/// The color to use when painting Layer borders.
ui.Color debugPaintLayerBordersColor = const ui.Color(0xFFFF9800);

/// Causes RenderObjects to paint warnings when painting outside their bounds.
bool debugPaintBoundsEnabled = false;

/// The color to use when painting RenderError boxes in checked mode.
ui.Color debugErrorBoxColor = const ui.Color(0xFFFF0000);

/// Prints a message to the console, which you can access using the "flutter"
/// tool's "logs" command ("flutter logs").
///
/// This function very crudely attempts to throttle the rate at which messages
/// are sent to avoid data loss on Android. This means that interleaving calls
/// to this function (directly or indirectly via [debugDumpRenderTree] or
/// [debugDumpApp]) and to the Dart [print] method can result in out-of-order
/// messages in the logs.
void debugPrint(String message) {
  _debugPrintBuffer.addAll(message.split('\n'));
  if (!_debugPrintScheduled)
    _debugPrintTask();
}
int _debugPrintedCharacters = 0;
int _kDebugPrintCapacity = 16 * 1024;
Duration _kDebugPrintPauseTime = const Duration(seconds: 1);
Queue<String> _debugPrintBuffer = new Queue<String>();
Stopwatch _debugPrintStopwatch = new Stopwatch();
bool _debugPrintScheduled = false;
void _debugPrintTask() {
  _debugPrintScheduled = false;
  if (_debugPrintStopwatch.elapsed > _kDebugPrintPauseTime) {
    _debugPrintStopwatch.stop();
    _debugPrintStopwatch.reset();
    _debugPrintedCharacters = 0;
  }
  while (_debugPrintedCharacters < _kDebugPrintCapacity && _debugPrintBuffer.length > 0) {
    String line = _debugPrintBuffer.removeFirst();
    _debugPrintedCharacters += line.length; // TODO(ianh): Use the UTF-8 byte length instead
    print(line);
  }
  if (_debugPrintBuffer.length > 0) {
    _debugPrintScheduled = true;
    _debugPrintedCharacters = 0;
    new Timer(_kDebugPrintPauseTime, _debugPrintTask);
  } else {
    _debugPrintStopwatch.start();
  }
}
