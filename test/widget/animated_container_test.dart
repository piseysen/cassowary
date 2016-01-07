// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

void main() {
  test('AnimatedContainer control test', () {
    testWidgets((WidgetTester tester) {
      GlobalKey key = new GlobalKey();

      BoxDecoration decorationA = new BoxDecoration(
        backgroundColor: new Color(0xFF00FF00)
      );

      BoxDecoration decorationB = new BoxDecoration(
        backgroundColor: new Color(0xFF0000FF)
      );

      BoxDecoration actualDecoration;

      tester.pumpWidget(
        new AnimatedContainer(
          key: key,
          duration: const Duration(milliseconds: 200),
          decoration: decorationA
        )
      );

      RenderDecoratedBox box = key.currentState.context.findRenderObject();
      actualDecoration = box.decoration;
      expect(actualDecoration.backgroundColor, equals(decorationA.backgroundColor));

      tester.pumpWidget(
        new AnimatedContainer(
          key: key,
          duration: const Duration(milliseconds: 200),
          decoration: decorationB
        )
      );

      expect(key.currentState.context.findRenderObject(), equals(box));
      actualDecoration = box.decoration;
      expect(actualDecoration.backgroundColor, equals(decorationA.backgroundColor));

      tester.pump(const Duration(seconds: 1));

      actualDecoration = box.decoration;
      expect(actualDecoration.backgroundColor, equals(decorationB.backgroundColor));

    });
  });

  test('AnimatedContainer overanimate test', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(
        new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: new BoxDecoration(
            backgroundColor: new Color(0xFF00FF00)
          )
        )
      );
      expect(tester.binding.transientCallbackCount, 0);
      tester.pump(new Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      tester.pumpWidget(
        new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: new BoxDecoration(
            backgroundColor: new Color(0xFF00FF00)
          )
        )
      );
      expect(tester.binding.transientCallbackCount, 0);
      tester.pump(new Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      tester.pumpWidget(
        new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: new BoxDecoration(
            backgroundColor: new Color(0xFF0000FF)
          )
        )
      );
      expect(tester.binding.transientCallbackCount, 1); // this is the only time an animation should have started!
      tester.pump(new Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      tester.pumpWidget(
        new AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: new BoxDecoration(
            backgroundColor: new Color(0xFF0000FF)
          )
        )
      );
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  test('Animation rerun', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(
        new Center(
          child: new AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100.0,
            height: 100.0,
            child: new Text('X')
          )
        )
      );

      tester.pump();
      tester.pump(new Duration(milliseconds: 100));

      RenderBox text = tester.findText('X').renderObject;
      expect(text.size.width, equals(100.0));
      expect(text.size.height, equals(100.0));

      tester.pump(new Duration(milliseconds: 1000));

      tester.pumpWidget(
        new Center(
          child: new AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200.0,
            height: 200.0,
            child: new Text('X')
          )
        )
      );
      tester.pump();
      tester.pump(new Duration(milliseconds: 100));

      text = tester.findText('X').renderObject;
      expect(text.size.width, greaterThan(110.0));
      expect(text.size.width, lessThan(190.0));
      expect(text.size.height, greaterThan(110.0));
      expect(text.size.height, lessThan(190.0));

      tester.pump(new Duration(milliseconds: 1000));

      expect(text.size.width, equals(200.0));
      expect(text.size.height, equals(200.0));

      tester.pumpWidget(
        new Center(
          child: new AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200.0,
            height: 100.0,
            child: new Text('X')
          )
        )
      );
      tester.pump();
      tester.pump(new Duration(milliseconds: 100));

      expect(text.size.width, equals(200.0));
      expect(text.size.height, greaterThan(110.0));
      expect(text.size.height, lessThan(190.0));

      tester.pump(new Duration(milliseconds: 1000));

      expect(text.size.width, equals(200.0));
      expect(text.size.height, equals(100.0));
    });
  });
}
