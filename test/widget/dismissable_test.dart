// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

const double itemExtent = 100.0;
Axis scrollDirection = Axis.vertical;
DismissDirection dismissDirection = DismissDirection.horizontal;
DismissDirection reportedDismissDirection;
List<int> dismissedItems = <int>[];

void handleOnResized(int item) {
  expect(dismissedItems.contains(item), isFalse);
}

void handleOnDismissed(DismissDirection direction, int item) {
  reportedDismissDirection = direction;
  expect(dismissedItems.contains(item), isFalse);
  dismissedItems.add(item);
}

Widget buildDismissableItem(int item) {
  return new Dismissable(
    key: new ValueKey<int>(item),
    direction: dismissDirection,
    onDismissed: (DismissDirection direction) { handleOnDismissed(direction, item); },
    onResized: () { handleOnResized(item); },
    child: new Container(
      width: itemExtent,
      height: itemExtent,
      child: new Text(item.toString())
    )
  );
}

Widget widgetBuilder() {
  return new Container(
    padding: const EdgeDims.all(10.0),
    child: new ScrollableList(
      scrollDirection: scrollDirection,
      itemExtent: itemExtent,
      children: <int>[0, 1, 2, 3, 4].where(
        (int i) => !dismissedItems.contains(i)
      ).map(buildDismissableItem)
    )
  );
}

void dismissElement(WidgetTester tester, Element itemElement, { DismissDirection gestureDirection }) {
  assert(itemElement != null);
  assert(gestureDirection != DismissDirection.horizontal);
  assert(gestureDirection != DismissDirection.vertical);

  Point downLocation;
  Point upLocation;
  switch(gestureDirection) {
    case DismissDirection.left:
      // getTopRight() returns a point that's just beyond itemWidget's right
      // edge and outside the Dismissable event listener's bounds.
      downLocation = tester.getTopRight(itemElement) + const Offset(-0.1, 0.0);
      upLocation = tester.getTopLeft(itemElement);
      break;
    case DismissDirection.right:
      // we do the same thing here to keep the test symmetric
      downLocation = tester.getTopLeft(itemElement) + const Offset(0.1, 0.0);
      upLocation = tester.getTopRight(itemElement);
      break;
    case DismissDirection.up:
      // getBottomLeft() returns a point that's just below itemWidget's bottom
      // edge and outside the Dismissable event listener's bounds.
      downLocation = tester.getBottomLeft(itemElement) + const Offset(0.0, -0.1);
      upLocation = tester.getTopLeft(itemElement);
      break;
    case DismissDirection.down:
      // again with doing the same here for symmetry
      downLocation = tester.getTopLeft(itemElement) + const Offset(0.1, 0.0);
      upLocation = tester.getBottomLeft(itemElement);
      break;
    default:
      fail("unsupported gestureDirection");
  }

  TestGesture gesture = tester.startGesture(downLocation, pointer: 5);
  gesture.moveTo(upLocation);
  gesture.up();
}

void dismissItem(WidgetTester tester, int item, { DismissDirection gestureDirection }) {
  assert(gestureDirection != DismissDirection.horizontal);
  assert(gestureDirection != DismissDirection.vertical);

  Element itemElement = tester.findText(item.toString());
  expect(itemElement, isNotNull);

  dismissElement(tester, itemElement, gestureDirection: gestureDirection);

  tester.pumpWidget(widgetBuilder()); // start the slide
  tester.pumpWidget(widgetBuilder(), const Duration(seconds: 1)); // finish the slide and start shrinking...
  tester.pumpWidget(widgetBuilder()); // first frame of shrinking animation
  tester.pumpWidget(widgetBuilder(), const Duration(seconds: 1)); // finish the shrinking and call the callback...
  tester.pumpWidget(widgetBuilder()); // rebuild after the callback removes the entry
}

class Test1215DismissableComponent extends StatelessComponent {
  Test1215DismissableComponent(this.text);
  final String text;
  Widget build(BuildContext context) {
    return new Dismissable(
      key: new ObjectKey(text),
      child: new AspectRatio(
        aspectRatio: 1.0,
        child: new Text(this.text)
      )
    );
  }
}

void main() {
  test('Horizontal drag triggers dismiss scrollDirection=vertical', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.vertical;
      dismissDirection = DismissDirection.horizontal;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.right);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
      expect(reportedDismissDirection, DismissDirection.right);

      dismissItem(tester, 1, gestureDirection: DismissDirection.left);
      expect(tester.findText('1'), isNull);
      expect(dismissedItems, equals([0, 1]));
      expect(reportedDismissDirection, DismissDirection.left);
    });
  });

  test('Vertical drag triggers dismiss scrollDirection=horizontal', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.horizontal;
      dismissDirection = DismissDirection.vertical;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.up);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
      expect(reportedDismissDirection, DismissDirection.up);

      dismissItem(tester, 1, gestureDirection: DismissDirection.down);
      expect(tester.findText('1'), isNull);
      expect(dismissedItems, equals([0, 1]));
      expect(reportedDismissDirection, DismissDirection.down);
    });
  });

  test('drag-left with DismissDirection.left triggers dismiss', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.vertical;
      dismissDirection = DismissDirection.left;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.right);
      expect(tester.findText('0'), isNotNull);
      expect(dismissedItems, isEmpty);
      dismissItem(tester, 1, gestureDirection: DismissDirection.right);

      dismissItem(tester, 0, gestureDirection: DismissDirection.left);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
      dismissItem(tester, 1, gestureDirection: DismissDirection.left);
    });
  });

  test('drag-right with DismissDirection.right triggers dismiss', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.vertical;
      dismissDirection = DismissDirection.right;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.left);
      expect(tester.findText('0'), isNotNull);
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.right);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
    });
  });

  test('drag-up with DismissDirection.up triggers dismiss', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.horizontal;
      dismissDirection = DismissDirection.up;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.down);
      expect(tester.findText('0'), isNotNull);
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.up);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
    });
  });

  test('drag-down with DismissDirection.down triggers dismiss', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.horizontal;
      dismissDirection = DismissDirection.down;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.up);
      expect(tester.findText('0'), isNotNull);
      expect(dismissedItems, isEmpty);

      dismissItem(tester, 0, gestureDirection: DismissDirection.down);
      expect(tester.findText('0'), isNull);
      expect(dismissedItems, equals([0]));
    });
  });

  // This is a regression test for an fn2 bug where dragging a card caused an
  // assert "'!_disqualifiedFromEverAppearingAgain' is not true". The old URL
  // was https://github.com/domokit/sky_engine/issues/1068 but that issue is 404
  // now since we migrated to the new repo. The bug was fixed by
  // https://github.com/flutter/engine/pull/1134 at the time, and later made
  // irrelevant by fn3, but just in case...
  test('Verify that drag-move events do not assert', () {
    testWidgets((WidgetTester tester) {
      scrollDirection = Axis.horizontal;
      dismissDirection = DismissDirection.down;
      dismissedItems = <int>[];

      tester.pumpWidget(widgetBuilder());
      Element itemElement = tester.findText('0');

      Point location = tester.getTopLeft(itemElement);
      Offset offset = new Offset(0.0, 5.0);
      TestGesture gesture = tester.startGesture(location, pointer: 5);
      gesture.moveBy(offset);
      tester.pumpWidget(widgetBuilder());
      gesture.moveBy(offset);
      tester.pumpWidget(widgetBuilder());
      gesture.moveBy(offset);
      tester.pumpWidget(widgetBuilder());
      gesture.moveBy(offset);
      tester.pumpWidget(widgetBuilder());
      gesture.up();
    });
  });

  // This one is for a case where dssmissing a component above a previously
  // dismissed component threw an exception, which was documented at the
  // now-obsolete URL https://github.com/flutter/engine/issues/1215 (the URL
  // died in the migration to the new repo). Don't copy this test; it doesn't
  // actually remove the dismissed widget, which is a violation of the
  // Dismissable contract. This is not an example of good practice.
  test('dismissing bottom then top (smoketest)', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(new Center(
        child: new Container(
          width: 100.0,
          height: 1000.0,
          child: new Column(
            children: <Widget>[
              new Test1215DismissableComponent('1'),
              new Test1215DismissableComponent('2')
            ]
          )
        )
      ));
      expect(tester.findText('1'), isNotNull);
      expect(tester.findText('2'), isNotNull);
      dismissElement(tester, tester.findText('2'), gestureDirection: DismissDirection.right);
      tester.pump(); // start the slide away
      tester.pump(new Duration(seconds: 1)); // finish the slide away
      expect(tester.findText('1'), isNotNull);
      expect(tester.findText('2'), isNull);
      dismissElement(tester, tester.findText('1'), gestureDirection: DismissDirection.right);
      tester.pump(); // start the slide away
      tester.pump(new Duration(seconds: 1)); // finish the slide away (at which point the child is no longer included in the tree)
      expect(tester.findText('1'), isNull);
      expect(tester.findText('2'), isNull);
    });
  });
}
