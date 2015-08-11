// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

/// Helper class to build a Paint DrawLooper that adds shadows to the Paint's
/// operation.
class ShadowDrawLooperBuilder {
  var builder_ = new sky.LayerDrawLooperBuilder();

  void addShadow(sky.Offset offset, sky.Color color, double blur) {
    builder_.addLayerOnTop(
          new sky.DrawLooperLayerInfo()
            ..setPaintBits(sky.PaintBits.all)
            ..setOffset(offset)
            ..setColorMode(sky.TransferMode.src),
          new sky.Paint()
            ..color = color
            ..setMaskFilter(new sky.MaskFilter.blur(sky.BlurStyle.normal, blur)));
  }

  sky.DrawLooper build() {
    builder_.addLayerOnTop(new sky.DrawLooperLayerInfo(), new sky.Paint());
    return builder_.build();
  }
}
