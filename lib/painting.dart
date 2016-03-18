// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The Flutter painting library.
///
/// This library includes a variety of classes that wrap the Flutter
/// engine's painting API for more specialised purposes, such as painting scaled
/// images, interpolating between shadows, painting borders around boxes, etc.
///
/// In particular:
///
///  * Use the [TextPainter] class for painting text.
///  * Use [Decoration] (and more concretely [BoxDecoration]) for
///    painting boxes.
library painting;

export 'src/painting/basic_types.dart';
export 'src/painting/box_painter.dart';
export 'src/painting/colors.dart';
export 'src/painting/decoration.dart';
export 'src/painting/edge_insets.dart';
export 'src/painting/text_editing.dart';
export 'src/painting/text_painter.dart';
export 'src/painting/text_style.dart';
export 'src/painting/transforms.dart';
