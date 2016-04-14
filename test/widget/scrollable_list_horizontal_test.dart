// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

const List<int> items = const <int>[0, 1, 2, 3, 4, 5];

Widget buildFrame(ViewportAnchor scrollAnchor) {
  return new Center(
    child: new Container(
      height: 50.0,
      child: new ScrollableList(
        itemExtent: 290.0,
        scrollDirection: Axis.horizontal,
        scrollAnchor: scrollAnchor,
        children: items.map((int item) {
          return new Container(
            child: new Text('$item')
          );
        })
      )
    )
  );
}

void main() {
  test('Drag horizontally with scroll anchor at top', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(buildFrame(ViewportAnchor.start));

      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('1'), const Offset(-300.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -10..280 = 1
      //   280..570 = 2
      //   570..860 = 3
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      // the center of item 3 is visible, so this works;
      // if item 3 was a bit wider, such that its center was past the 800px mark, this would fail,
      // because it wouldn't be hit tested when scrolling from its center, as scroll() does.
      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('3'), const Offset(-290.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -10..280 = 2
      //   280..570 = 3
      //   570..860 = 4
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('3'), const Offset(0.0, -290.0));
      tester.pump(const Duration(seconds: 1));
      // unchanged
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('3'), const Offset(-290.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -10..280 = 3
      //   280..570 = 4
      //   570..860 = 5
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, doesNotHaveWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, hasWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      // at this point we can drag 60 pixels further before we hit the friction zone
      // then, every pixel we drag is equivalent to half a pixel of movement
      // to move item 3 entirely off screen therefore takes:
      //  60 + (290-60)*2 = 520 pixels
      // plus a couple more to be sure
      tester.scroll(find.text('3'), const Offset(-522.0, 0.0));
      tester.pump(); // just after release
      // screen is 800px wide, and has the following items:
      //   -11..279 = 4
      //   279..569 = 5
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, doesNotHaveWidget(find.text('2')));
      expect(tester, doesNotHaveWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, hasWidget(find.text('5')));
      tester.pump(const Duration(seconds: 1)); // a second after release
      // screen is 800px wide, and has the following items:
      //   -70..220 = 3
      //   220..510 = 4
      //   510..800 = 5
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, doesNotHaveWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, hasWidget(find.text('5')));

      tester.pumpWidget(new Container());
      tester.pumpWidget(buildFrame(ViewportAnchor.start), const Duration(seconds: 1));
      tester.scroll(find.text('2'), const Offset(-280.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //  -280..10  = 0
      //    10..300 = 1
      //   300..590 = 2
      //   590..880 = 3
      expect(tester, hasWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));
      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('2'), const Offset(-290.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //  -280..10  = 1
      //    10..300 = 2
      //   300..590 = 3
      //   590..880 = 4
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));
    });
  });

  test('Drag horizontally with scroll anchor at end', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(buildFrame(ViewportAnchor.end));

      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -70..220 = 3
      //   220..510 = 4
      //   510..800 = 5
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, doesNotHaveWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, hasWidget(find.text('5')));

      tester.scroll(find.text('5'), const Offset(300.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -80..210 = 2
      //   230..520 = 3
      //   520..810 = 4
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, doesNotHaveWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, hasWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      // the center of item 3 is visible, so this works;
      // if item 3 was a bit wider, such that its center was past the 800px mark, this would fail,
      // because it wouldn't be hit tested when scrolling from its center, as scroll() does.
      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('3'), const Offset(290.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -10..280 = 1
      //   280..570 = 2
      //   570..860 = 3
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('3'), const Offset(0.0, 290.0));
      tester.pump(const Duration(seconds: 1));
      // unchanged
      expect(tester, doesNotHaveWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, hasWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      tester.scroll(find.text('2'), const Offset(290.0, 0.0));
      tester.pump(const Duration(seconds: 1));
      // screen is 800px wide, and has the following items:
      //   -10..280 = 0
      //   280..570 = 1
      //   570..860 = 2
      expect(tester, hasWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, doesNotHaveWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));

      tester.pump(const Duration(seconds: 1));
      // at this point we can drag 60 pixels further before we hit the friction zone
      // then, every pixel we drag is equivalent to half a pixel of movement
      // to move item 3 entirely off screen therefore takes:
      //  60 + (290-60)*2 = 520 pixels
      // plus a couple more to be sure
      tester.scroll(find.text('1'), const Offset(522.0, 0.0));
      tester.pump(); // just after release
      // screen is 800px wide, and has the following items:
      //   280..570 = 0
      //   570..860 = 1
      expect(tester, hasWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, doesNotHaveWidget(find.text('2')));
      expect(tester, doesNotHaveWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));
      tester.pump(const Duration(seconds: 1)); // a second after release
      // screen is 800px wide, and has the following items:
      //     0..290 = 0
      //   290..580 = 1
      //   580..870 = 2
      expect(tester, hasWidget(find.text('0')));
      expect(tester, hasWidget(find.text('1')));
      expect(tester, hasWidget(find.text('2')));
      expect(tester, doesNotHaveWidget(find.text('3')));
      expect(tester, doesNotHaveWidget(find.text('4')));
      expect(tester, doesNotHaveWidget(find.text('5')));
    });
  });
}
