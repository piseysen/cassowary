// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart';

import 'test_semantics.dart';

// This file uses "as dynamic" in a few places to defeat the static
// analysis. In general you want to avoid using this style in your
// code, as it will cause the analyzer to be unable to help you catch
// errors.
//
// In this case, we do it because we are trying to call internal
// methods of the tooltip code in order to test it. Normally, the
// state of a tooltip is a private class, but by using a GlobalKey we
// can get a handle to that object and by using "as dynamic" we can
// bypass the analyzer's type checks and call methods that we aren't
// supposed to be able to know about.
//
// It's ok to do this in tests, but you really don't want to do it in
// production code.

void main() {
  test('Does tooltip end up in the right place - top left', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 0.0,
                      top: 0.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 20.0,
                        padding: const EdgeInsets.all(5.0),
                        verticalOffset: 20.0,
                        screenEdgeMargin: const EdgeInsets.all(10.0),
                        preferBelow: false,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      /********************* 800x600 screen
       *o                  * y=0
       *|                  * }- 20.0 vertical offset, of which 10.0 is in the screen edge margin
       *+----+             * \- (5.0 padding in height)
       *|    |             * |- 20 height
       *+----+             * /- (5.0 padding in height)
       *                   *
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent.parent.parent.parent.parent;
      expect(tip.size.height, equals(20.0)); // 10.0 height + 5.0 padding * 2 (top, bottom)
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)), equals(const Point(10.0, 20.0)));
    });
  });

  test('Does tooltip end up in the right place - center prefer above fits', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 400.0,
                      top: 300.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 100.0,
                        padding: const EdgeInsets.all(0.0),
                        verticalOffset: 100.0,
                        screenEdgeMargin: const EdgeInsets.all(100.0),
                        preferBelow: false,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      /********************* 800x600 screen
       *        ___        * }-100.0 margin
       *       |___|       * }-100.0 height
       *         |         * }-100.0 vertical offset
       *         o         * y=300.0
       *                   *
       *                   *
       *                   *
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent;
      expect(tip.size.height, equals(100.0));
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)).y, equals(100.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).y, equals(200.0));
    });
  });

  test('Does tooltip end up in the right place - center prefer above does not fit', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 400.0,
                      top: 299.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 100.0,
                        padding: const EdgeInsets.all(0.0),
                        verticalOffset: 100.0,
                        screenEdgeMargin: const EdgeInsets.all(100.0),
                        preferBelow: false,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      // we try to put it here but it doesn't fit:
      /********************* 800x600 screen
       *        ___        * }-100.0 margin
       *       |___|       * }-100.0 height (starts at y=99.0)
       *         |         * }-100.0 vertical offset
       *         o         * y=299.0
       *                   *
       *                   *
       *                   *
       *********************/

      // so we put it here:
      /********************* 800x600 screen
       *                   *
       *                   *
       *         o         * y=299.0
       *        _|_        * }-100.0 vertical offset
       *       |___|       * }-100.0 height
       *                   * }-100.0 margin
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent;
      expect(tip.size.height, equals(100.0));
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)).y, equals(399.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).y, equals(499.0));
    });
  });

  test('Does tooltip end up in the right place - center prefer below fits', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 400.0,
                      top: 300.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 100.0,
                        padding: const EdgeInsets.all(0.0),
                        verticalOffset: 100.0,
                        screenEdgeMargin: const EdgeInsets.all(100.0),
                        preferBelow: true,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      /********************* 800x600 screen
       *                   *
       *                   *
       *         o         * y=300.0
       *        _|_        * }-100.0 vertical offset
       *       |___|       * }-100.0 height
       *                   * }-100.0 margin
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent;
      expect(tip.size.height, equals(100.0));
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)).y, equals(400.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).y, equals(500.0));
    });
  });

  test('Does tooltip end up in the right place - way off to the right', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 1600.0,
                      top: 300.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 10.0,
                        padding: const EdgeInsets.all(0.0),
                        verticalOffset: 10.0,
                        screenEdgeMargin: const EdgeInsets.all(10.0),
                        preferBelow: true,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      /********************* 800x600 screen
       *                   *
       *                   *
       *                   * y=300.0;   target -->   o
       *              ___| * }-10.0 vertical offset
       *             |___| * }-10.0 height
       *                   *
       *                   * }-10.0 margin
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent;
      expect(tip.size.height, equals(10.0));
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)).y, equals(310.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).x, equals(790.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).y, equals(320.0));
    });
  });

  test('Does tooltip end up in the right place - near the edge', () {
    testElementTree((ElementTreeTester tester) {
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 780.0,
                      top: 300.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        height: 10.0,
                        padding: const EdgeInsets.all(0.0),
                        verticalOffset: 10.0,
                        screenEdgeMargin: const EdgeInsets.all(10.0),
                        preferBelow: true,
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(
                          width: 0.0,
                          height: 0.0
                        )
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      (key.currentState as dynamic).showTooltip(); // before using "as dynamic" in your code, see note top of file
      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)

      /********************* 800x600 screen
       *                   *
       *                   *
       *                o  * y=300.0
       *              __|  * }-10.0 vertical offset
       *             |___| * }-10.0 height
       *                   *
       *                   * }-10.0 margin
       *********************/

      RenderBox tip = tester.findText('TIP').renderObject.parent;
      expect(tip.size.height, equals(10.0));
      expect(tip.localToGlobal(tip.size.topLeft(Point.origin)).y, equals(310.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).x, equals(790.0));
      expect(tip.localToGlobal(tip.size.bottomRight(Point.origin)).y, equals(320.0));
    });
  });

  test('Does tooltip contribute semantics', () {
    testElementTree((ElementTreeTester tester) {
      TestSemanticsListener client = new TestSemanticsListener();
      GlobalKey key = new GlobalKey();
      tester.pumpWidget(
        new Overlay(
          initialEntries: <OverlayEntry>[
            new OverlayEntry(
              builder: (BuildContext context) {
                return new Stack(
                  children: <Widget>[
                    new Positioned(
                      left: 780.0,
                      top: 300.0,
                      child: new Tooltip(
                        key: key,
                        message: 'TIP',
                        fadeDuration: const Duration(seconds: 1),
                        showDuration: const Duration(seconds: 2),
                        child: new Container(width: 0.0, height: 0.0)
                      )
                    ),
                  ]
                );
              }
            ),
          ]
        )
      );
      expect(client.updates.length, equals(2));
      expect(client.updates[0].id, equals(0));
      expect(client.updates[0].flags.canBeTapped, isFalse);
      expect(client.updates[0].flags.canBeLongPressed, isFalse);
      expect(client.updates[0].flags.canBeScrolledHorizontally, isFalse);
      expect(client.updates[0].flags.canBeScrolledVertically, isFalse);
      expect(client.updates[0].flags.hasCheckedState, isFalse);
      expect(client.updates[0].flags.isChecked, isFalse);
      expect(client.updates[0].strings.label, equals('TIP'));
      expect(client.updates[0].geometry.transform, isNull);
      expect(client.updates[0].geometry.left, equals(0.0));
      expect(client.updates[0].geometry.top, equals(0.0));
      expect(client.updates[0].geometry.width, equals(800.0));
      expect(client.updates[0].geometry.height, equals(600.0));
      expect(client.updates[0].children.length, equals(0));
      expect(client.updates[1], isNull);
      client.updates.clear();

      // before using "as dynamic" in your code, see note top of file
      (key.currentState as dynamic).showTooltip(); // this triggers a rebuild of the semantics because the tree changes

      tester.pump(const Duration(seconds: 2)); // faded in, show timer started (and at 0.0)
      expect(client.updates.length, equals(2));
      expect(client.updates[0].id, equals(0));
      expect(client.updates[0].flags.canBeTapped, isFalse);
      expect(client.updates[0].flags.canBeLongPressed, isFalse);
      expect(client.updates[0].flags.canBeScrolledHorizontally, isFalse);
      expect(client.updates[0].flags.canBeScrolledVertically, isFalse);
      expect(client.updates[0].flags.hasCheckedState, isFalse);
      expect(client.updates[0].flags.isChecked, isFalse);
      expect(client.updates[0].strings.label, equals('TIP'));
      expect(client.updates[0].geometry.transform, isNull);
      expect(client.updates[0].geometry.left, equals(0.0));
      expect(client.updates[0].geometry.top, equals(0.0));
      expect(client.updates[0].geometry.width, equals(800.0));
      expect(client.updates[0].geometry.height, equals(600.0));
      expect(client.updates[0].children.length, equals(0));
      expect(client.updates[1], isNull);
      client.updates.clear();
    });
  });
}
