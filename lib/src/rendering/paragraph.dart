// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';

import 'box.dart';
import 'object.dart';

export 'package:flutter/painting.dart' show
  FontStyle,
  FontWeight,
  PlainTextSpan,
  StyledTextSpan,
  TextAlign,
  TextBaseline,
  TextDecoration,
  TextDecorationStyle,
  TextSpan,
  TextStyle;

/// A render object that displays a paragraph of text
class RenderParagraph extends RenderBox {

  RenderParagraph(
    TextSpan text
  ) : _textPainter = new TextPainter(text) {
    assert(text != null);
  }

  final TextPainter _textPainter;

  BoxConstraints _constraintsForCurrentLayout; // when null, we don't have a current layout

  /// The text to display
  TextSpan get text => _textPainter.text;
  void set text(TextSpan value) {
    if (_textPainter.text == value)
      return;
    _textPainter.text = value;
    _constraintsForCurrentLayout = null;
    markNeedsLayout();
  }

  // TODO(abarth): This logic should live in TextPainter and be shared with RenderEditableLine.
  void _layoutText(BoxConstraints constraints) {
    assert(constraints != null);
    assert(constraints.isNormalized);
    if (_constraintsForCurrentLayout == constraints)
      return; // already cached this layout
    _textPainter.maxWidth = constraints.maxWidth;
    _textPainter.minWidth = constraints.minWidth;
    _textPainter.minHeight = constraints.minHeight;
    _textPainter.maxHeight = constraints.maxHeight;
    _textPainter.layout();
    // By default, we shrinkwrap to the intrinsic width.
    double width = constraints.constrainWidth(_textPainter.maxIntrinsicWidth);
    _textPainter.minWidth = width;
    _textPainter.maxWidth = width;
    _textPainter.layout();
    _constraintsForCurrentLayout = constraints;
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    _layoutText(constraints);
    return constraints.constrainWidth(_textPainter.minIntrinsicWidth);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    _layoutText(constraints);
    return constraints.constrainWidth(_textPainter.maxIntrinsicWidth);
  }

  double _getIntrinsicHeight(BoxConstraints constraints) {
    _layoutText(constraints);
    return constraints.constrainHeight(_textPainter.size.height);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.isNormalized);
    return _getIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.isNormalized);
    return _getIntrinsicHeight(constraints);
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!needsLayout);
    _layoutText(constraints);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  bool hitTestSelf(Point position) => true;

  void performLayout() {
    _layoutText(constraints);
    size = constraints.constrain(_textPainter.size);
  }

  void paint(PaintingContext context, Offset offset) {
    // Ideally we could compute the min/max intrinsic width/height with a
    // non-destructive operation. However, currently, computing these values
    // will destroy state inside the painter. If that happens, we need to
    // get back the correct state by calling _layout again.
    //
    // TODO(abarth): Make computing the min/max intrinsic width/height
    // a non-destructive operation.
    _layoutText(constraints);
    _textPainter.paint(context.canvas, offset);
  }

  // we should probably expose a way to do precise (inter-glpyh) hit testing

  String debugDescribeChildren(String prefix) {
    return '$prefix \u2558\u2550\u2566\u2550\u2550 text \u2550\u2550\u2550\n'
           '${text.toString("$prefix   \u2551 ")}\n'
           '$prefix   \u255A\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\n'
           '$prefix\n';
  }
}
