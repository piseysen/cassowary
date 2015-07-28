// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky';
import 'dart:math' as math;

double timeBase = null;

void beginFrame(double timeStamp) {
  tracing.begin('beginFrame');
  if (timeBase == null)
    timeBase = timeStamp;
  double delta = timeStamp - timeBase;
  PictureRecorder recorder = new PictureRecorder();
  Canvas canvas = new Canvas(recorder, new Rect.fromLTWH(0.0, 0.0, view.width, view.height));
  canvas.translate(view.width / 2.0, view.height / 2.0);
  canvas.rotate(math.PI * delta / 1800);
  canvas.drawRect(new Rect.fromLTRB(-100.0, -100.0, 100.0, 100.0),
                  new Paint()..color = const Color.fromARGB(255, 0, 255, 0));
  view.picture = recorder.endRecording();
  view.scheduleFrame();
  tracing.end('beginFrame');
}

void main() {
  view.setFrameCallback(beginFrame);
  view.scheduleFrame();
}
