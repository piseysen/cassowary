// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

// Any changes to this file should be reflected in the debugAssertAllSchedulerVarsUnset()
// function below.

/// Print a banner at the beginning of each frame.
///
/// Frames triggered by the engine and handler by the scheduler binding will
/// have a banner giving the frame number and the time stamp of the frame.
///
/// Frames triggered eagerly by the widget framework (e.g. when calling
/// [runApp]) will have a label saying "warm-up frame" instead of the time stamp
/// (the time stamp sent to frame callbacks in that case is the time of the last
/// frame, or 0:00 if it is the first frame).
///
/// To include a banner at the end of each frame as well, to distinguish
/// intra-frame output from inter-frame output, set [debugPrintEndFrameBanner]
/// to true as well.
///
/// See [SchedulerBinding.beginFrame].
bool debugPrintBeginFrameBanner = false;

/// Print a banner at the end of each frame.
///
/// Combined with [debugPrintBeginFrameBanner], this can be helpful for
/// determining if code is running during a frame or between frames.
bool debugPrintEndFrameBanner = false;

/// Returns true if none of the scheduler library debug variables have been changed.
///
/// This function is used by the test framework to ensure that debug variables
/// haven't been inadvertently changed.
///
/// See [https://docs.flutter.io/flutter/scheduler/scheduler-library.html] for
/// a complete list.
bool debugAssertAllSchedulerVarsUnset(String reason) {
  assert(() {
    if (debugPrintBeginFrameBanner ||
        debugPrintEndFrameBanner) {
      throw new FlutterError(reason);
    }
    return true;
  });
  return true;
}
