// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

/// Indicates whether we're running with asserts enabled.
final bool inDebugBuild = _initInDebugBuild();

bool _initInDebugBuild() {
  bool _inDebug = false;
  bool setAssert() {
    _inDebug = true;
    return true;
  }
  assert(setAssert());
  return _inDebug;
}

/// Causes each RenderBox to paint a box around its bounds.
bool debugPaintSizeEnabled = false;

/// The color to use when painting RenderObject bounds.
sky.Color debugPaintSizeColor = const sky.Color(0xFF00FFFF);

/// Causes each RenderBox to paint a line at each of its baselines.
bool debugPaintBaselinesEnabled = false;

/// The color to use when painting alphabetic baselines.
sky.Color debugPaintAlphabeticBaselineColor = const sky.Color(0xFF00FF00);

/// The color ot use when painting ideographic baselines.
sky.Color debugPaintIdeographicBaselineColor = const sky.Color(0xFFFFD000);

/// Causes each Layer to paint a box around its bounds.
bool debugPaintLayerBordersEnabled = false;

/// The color to use when painting Layer borders.
sky.Color debugPaintLayerBordersColor = const sky.Color(0xFFFF9800);

/// Causes RenderObjects to paint warnings when painting outside their bounds.
bool debugPaintBoundsEnabled = false;

/// The color to use when painting RenderError boxes in checked mode.
sky.Color debugErrorBoxColor = const sky.Color(0xFFFF0000);

/// How many lines of debugging output to include when an exception is reported.
int debugRenderObjectDumpMaxLength = 10;
