// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:test/test.dart';

import 'rendering_tester.dart';

class TestBlockPainter extends RenderObjectPainter {
  void paint(PaintingContext context, Offset offset) { }
}

void main() {
  test('block intrinsics', () {
    RenderParagraph paragraph = new RenderParagraph(
      new TextSpan(
        style: new TextStyle(height: 1.0),
        text: 'Hello World'
      )
    );
    const BoxConstraints unconstrained = const BoxConstraints();
    double textWidth = paragraph.getMaxIntrinsicWidth(unconstrained);
    double oneLineTextHeight = paragraph.getMinIntrinsicHeight(unconstrained);
    final BoxConstraints constrained = new BoxConstraints(maxWidth: textWidth * 0.9);
    double wrappedTextWidth = paragraph.getMinIntrinsicWidth(unconstrained);
    double twoLinesTextHeight = paragraph.getMinIntrinsicHeight(constrained);

    // controls
    expect(wrappedTextWidth, lessThan(textWidth));
    expect(paragraph.getMinIntrinsicWidth(unconstrained), equals(wrappedTextWidth));
    expect(paragraph.getMaxIntrinsicWidth(constrained), equals(constrained.maxWidth));

    expect(oneLineTextHeight, lessThan(twoLinesTextHeight));
    expect(twoLinesTextHeight, lessThan(oneLineTextHeight * 3.0));
    expect(paragraph.getMaxIntrinsicHeight(unconstrained), equals(oneLineTextHeight));
    expect(paragraph.getMaxIntrinsicHeight(constrained), equals(twoLinesTextHeight));

    RenderBox testBlock = new RenderBlock(
      children: <RenderBox>[
        paragraph,
      ]
    );
    expect(testBlock.getMinIntrinsicWidth(unconstrained), equals(wrappedTextWidth));
    expect(testBlock.getMinIntrinsicWidth(constrained), equals(wrappedTextWidth));
    expect(testBlock.getMaxIntrinsicWidth(unconstrained), equals(textWidth));
    expect(testBlock.getMaxIntrinsicWidth(constrained), equals(constrained.maxWidth));
    expect(testBlock.getMinIntrinsicHeight(unconstrained), equals(oneLineTextHeight));
    expect(testBlock.getMinIntrinsicHeight(constrained), equals(twoLinesTextHeight));
    expect(testBlock.getMaxIntrinsicHeight(unconstrained), equals(oneLineTextHeight));
    expect(testBlock.getMaxIntrinsicHeight(constrained), equals(twoLinesTextHeight));

    final BoxConstraints empty = new BoxConstraints.tight(Size.zero);
    expect(testBlock.getMinIntrinsicWidth(empty), equals(0.0));
    expect(testBlock.getMaxIntrinsicWidth(empty), equals(0.0));
    expect(testBlock.getMinIntrinsicHeight(empty), equals(0.0));
    expect(testBlock.getMaxIntrinsicHeight(empty), equals(0.0));
  });


  test('overlay painters can attach and detach', () {
    TestBlockPainter first = new TestBlockPainter();
    TestBlockPainter second = new TestBlockPainter();
    RenderBlockViewport block = new RenderBlockViewport(overlayPainter: first);

    // The first painter isn't attached because we haven't attached block.
    expect(first.renderObject, isNull);
    expect(second.renderObject, isNull);

    block.overlayPainter = second;

    expect(first.renderObject, isNull);
    expect(second.renderObject, isNull);

    layout(block);

    expect(first.renderObject, isNull);
    expect(second.renderObject, equals(block));

    block.overlayPainter = first;

    expect(first.renderObject, equals(block));
    expect(second.renderObject, isNull);
  });
}
