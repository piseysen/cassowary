// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:test/test.dart';

import 'rendering_tester.dart';

class RenderLayoutTestBox extends RenderProxyBox {
  RenderLayoutTestBox(this.onLayout);
  final VoidCallback onLayout;
  void layout(Constraints constraints, { bool parentUsesSize: false }) {
    // Doing this in tests is ok, but if you're writing your own
    // render object, you want to override performLayout(), not
    // layout(). Overriding layout() would remove many critical
    // performance optimizations of the rendering system, as well as
    // many bypassing many checked-mode integrity checks.
    super.layout(constraints, parentUsesSize: parentUsesSize);
    onLayout();
  }
  bool get sizedByParent => true;
  void performLayout() { }
}

void main() {
  test('moving children', () {
    RenderBox child1, child2;
    bool movedChild1 = false;
    bool movedChild2 = false;
    RenderFlex block = new RenderFlex();
    block.add(child1 = new RenderLayoutTestBox(() { movedChild1 = true; }));
    block.add(child2 = new RenderLayoutTestBox(() { movedChild2 = true; }));

    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);
    layout(block);
    expect(movedChild1, isTrue);
    expect(movedChild2, isTrue);

    movedChild1 = false;
    movedChild2 = false;

    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);
    pumpFrame();
    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);

    block.move(child1, after: child2);
    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);
    pumpFrame();
    expect(movedChild1, isTrue);
    expect(movedChild2, isTrue);

    movedChild1 = false;
    movedChild2 = false;

    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);
    pumpFrame();
    expect(movedChild1, isFalse);
    expect(movedChild2, isFalse);
  });
}
