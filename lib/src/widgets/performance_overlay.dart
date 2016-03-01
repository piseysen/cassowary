// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'framework.dart';

/// Displays performance statistics.
class PerformanceOverlay extends LeafRenderObjectWidget {
  // TODO(abarth): We should have a page on the web site with a screenshot and
  // an explanation of all the various readouts.

  /// Create a performance overlay that only displays specific statistics. The
  /// mask is created by shifting 1 by the index of the specific
  /// [StatisticOption] to enable.
  PerformanceOverlay({ this.optionsMask, this.rasterizerThreshold: 0, Key key }) : super(key: key);

  /// Create a performance overlay that displays all available statistics
  PerformanceOverlay.allEnabled({ Key key, this.rasterizerThreshold: 0 })
    : optionsMask = (
        1 << PerformanceOverlayOption.displayRasterizerStatistics.index |
        1 << PerformanceOverlayOption.visualizeRasterizerStatistics.index |
        1 << PerformanceOverlayOption.displayEngineStatistics.index |
        1 << PerformanceOverlayOption.visualizeEngineStatistics.index
      ),
      super(key: key);

  final int optionsMask;

  /// The rasterizer threshold is an integer specifying the number of frame
  /// intervals that the rasterizer must miss before it decides that the frame
  /// is suitable for capturing an SkPicture trace for further analysis.
  ///
  /// For example, if you want a trace of all pictures that could not be
  /// renderered by the rasterizer within the frame boundary (and hence caused
  /// jank), specify 1. Specifying 2 will trace all pictures that took more
  /// more than 2 frame intervals to render. Adjust this value to only capture
  /// the particularly expensive pictures while skipping the others. Specifying
  /// 0 disables all capture.
  ///
  /// Captured traces are placed on your device in the application documents
  /// directory in this form "trace_<collection_time>.skp". These can
  /// be viewed in the Skia debugger.
  ///
  /// Notes:
  /// The rasterizer only takes into account the time it took to render
  /// the already constructed picture. This include the Skia calls (which is
  /// also why an SkPicture trace is generated) but not any of the time spent in
  /// dart to construct that picture. To profile that part of your code, use
  /// the instrumentation available in observatory.
  ///
  /// To decide what threshold interval to use, count the number of horizontal
  /// lines displayed in the performance overlay for the rasterizer (not the
  /// engine). That should give an idea of how often frames are skipped (and by
  /// how many frame intervals).
  final int rasterizerThreshold;

  RenderPerformanceOverlay createRenderObject() => new RenderPerformanceOverlay(
    optionsMask: optionsMask,
    rasterizerThreshold: rasterizerThreshold
  );

  void updateRenderObject(RenderPerformanceOverlay renderObject, RenderObjectWidget oldWidget) {
    renderObject
      ..optionsMask = optionsMask
      ..rasterizerThreshold = rasterizerThreshold;
  }
}
