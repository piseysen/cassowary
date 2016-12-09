// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

final List<String> menuItems = <String>['one', 'two', 'three', 'four'];

Widget buildFrame({
    Key buttonKey,
    String value: 'two',
    ValueChanged<String> onChanged,
    bool isDense: false,
    Widget hint,
  }) {
  return new MaterialApp(
    home: new Material(
      child: new Center(
        child: new DropdownButton<String>(
          key: buttonKey,
          value: value,
          hint: hint,
          onChanged: onChanged,
          isDense: isDense,
          items: menuItems.map((String item) {
            return new DropdownMenuItem<String>(
              key: new ValueKey<String>(item),
              value: item,
              child: new Text(item, key: new ValueKey<String>(item + "Text")),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

// When the dropdown's menu is popped up, a RenderParagraph for the selected
// menu's text item will appear both in the dropdown button and in the menu.
// The RenderParagraphs should be aligned, i.e. they should have the same
// size and location.
void checkSelectedItemTextGeometry(WidgetTester tester, String value) {
  final List<RenderBox> boxes = tester.renderObjectList(find.byKey(new ValueKey<String>(value + 'Text'))).toList();
  expect(boxes.length, equals(2));
  final RenderBox box0 = boxes[0];
  final RenderBox box1 = boxes[1];
  expect(box0.localToGlobal(Point.origin), equals(box1.localToGlobal(Point.origin)));
  expect(box0.size, equals(box1.size));
}

bool sameGeometry(RenderBox box1, RenderBox box2) {
  expect(box1.localToGlobal(Point.origin), equals(box2.localToGlobal(Point.origin)));
  expect(box1.size.height, equals(box2.size.height));
  return true;
}


void main() {
  testWidgets('Drop down button control test', (WidgetTester tester) async {
    String value = 'one';
    void didChangeValue(String newValue) {
      value = newValue;
    }

    Widget build() => buildFrame(value: value, onChanged: didChangeValue);

    await tester.pumpWidget(build());

    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('one'));

    await tester.tap(find.text('three').last);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('three'));

    await tester.tap(find.text('three'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('three'));

    await tester.pumpWidget(build());

    await tester.tap(find.text('two').last);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('two'));
  });

  testWidgets('Drop down button with no app', (WidgetTester tester) async {
    String value = 'one';
    void didChangeValue(String newValue) {
      value = newValue;
    }

    Widget build() {
      return new Navigator(
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          return new MaterialPageRoute<Null>(
            settings: settings,
            builder: (BuildContext context) {
              return new Material(
                child: buildFrame(value: 'one', onChanged: didChangeValue),
              );
            },
          );
        }
      );
    }

    await tester.pumpWidget(build());

    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('one'));

    await tester.tap(find.text('three').last);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('three'));

    await tester.tap(find.text('three'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('three'));

    await tester.pumpWidget(build());

    await tester.tap(find.text('two').last);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    expect(value, equals('two'));
  });

  testWidgets('Drop down screen edges', (WidgetTester tester) async {
    int value = 4;
    List<DropdownMenuItem<int>> items = <DropdownMenuItem<int>>[];
    for (int i = 0; i < 20; ++i)
      items.add(new DropdownMenuItem<int>(value: i, child: new Text('$i')));

    void handleChanged(int newValue) {
      value = newValue;
    }

    DropdownButton<int> button = new DropdownButton<int>(
      value: value,
      onChanged: handleChanged,
      items: items,
    );

    await tester.pumpWidget(
      new MaterialApp(
        home: new Material(
          child: new Align(
            alignment: FractionalOffset.topCenter,
            child: button,
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    // We should have two copies of item 5, one in the menu and one in the
    // button itself.
    expect(tester.elementList(find.text('5')), hasLength(2));

    // We should only have one copy of item 19, which is in the button itself.
    // The copy in the menu shouldn't be in the tree because it's off-screen.
    expect(tester.elementList(find.text('19')), hasLength(1));

    expect(value, 4);
    await tester.tap(find.byConfig(button));
    expect(value, 4);
    // this waits for the route's completer to complete, which calls handleChanged
    await tester.idle();
    expect(value, 4);

    // TODO(abarth): Remove these calls to pump once navigator cleans up its
    // pop transitions.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation
  });

  testWidgets('Drop down button aligns selected menu item', (WidgetTester tester) async {
    Key buttonKey = new UniqueKey();
    String value = 'two';

    Widget build() => buildFrame(buttonKey: buttonKey, value: value);

    await tester.pumpWidget(build());
    RenderBox buttonBox = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBox.attached);
    Point buttonOriginBeforeTap = buttonBox.localToGlobal(Point.origin);

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    // Tapping the dropdown button should not cause it to move.
    expect(buttonBox.localToGlobal(Point.origin), equals(buttonOriginBeforeTap));

    // The selected dropdown item is both in menu we just popped up, and in
    // the IndexedStack contained by the dropdown button. Both of them should
    // have the same origin and height as the dropdown button.
    List<RenderObject> itemBoxes = tester.renderObjectList(find.byKey(const ValueKey<String>('two'))).toList();
    expect(itemBoxes.length, equals(2));
    for(RenderBox itemBox in itemBoxes) {
      assert(itemBox.attached);
      expect(buttonBox.localToGlobal(Point.origin), equals(itemBox.localToGlobal(Point.origin)));
      expect(buttonBox.size.height, equals(itemBox.size.height));
    }

    // The two RenderParagraph objects, for the 'two' items' Text children,
    // should have the same size and location.
    checkSelectedItemTextGeometry(tester, 'two');
  });

  testWidgets('Drop down button with isDense:true aligns selected menu item', (WidgetTester tester) async {
    Key buttonKey = new UniqueKey();
    String value = 'two';

    Widget build() => buildFrame(buttonKey: buttonKey, value: value, isDense: true);

    await tester.pumpWidget(build());
    RenderBox buttonBox = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBox.attached);

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    // The selected dropdown item is both in menu we just popped up, and in
    // the IndexedStack contained by the dropdown button. Both of them should
    // have the same vertical center as the button.
    List<RenderBox> itemBoxes = tester.renderObjectList(find.byKey(const ValueKey<String>('two'))).toList();
    expect(itemBoxes.length, equals(2));

    // When isDense is true, the button's height is reduced. The menu items'
    // heights are not.
    double menuItemHeight = itemBoxes.map((RenderBox box) => box.size.height).reduce(math.max);
    expect(menuItemHeight, greaterThan(buttonBox.size.height));

    for(RenderBox itemBox in itemBoxes) {
      assert(itemBox.attached);
      Point buttonBoxCenter = buttonBox.size.center(buttonBox.localToGlobal(Point.origin));
      Point itemBoxCenter =  itemBox.size.center(itemBox.localToGlobal(Point.origin));
      expect(buttonBoxCenter.y, equals(itemBoxCenter.y));
    }

    // The two RenderParagraph objects, for the 'two' items' Text children,
    // should have the same size and location.
    checkSelectedItemTextGeometry(tester, 'two');
  });

  testWidgets('Size of DropdownButton with null value', (WidgetTester tester) async {
    Key buttonKey = new UniqueKey();
    String value;

    Widget build() => buildFrame(buttonKey: buttonKey, value: value);

    await tester.pumpWidget(build());
    RenderBox buttonBoxNullValue = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBoxNullValue.attached);


    value = 'three';
    await tester.pumpWidget(build());
    RenderBox buttonBox = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBox.attached);

    // A DropDown button with a null value should be the same size as a
    // one with a non-null value.
    expect(buttonBox.localToGlobal(Point.origin), equals(buttonBoxNullValue.localToGlobal(Point.origin)));
    expect(buttonBox.size, equals(buttonBoxNullValue.size));
  });

  testWidgets('Layout of a DropdownButton with null value', (WidgetTester tester) async {
    Key buttonKey = new UniqueKey();
    String value;

    void onChanged(String newValue) {
      value = newValue;
    }

    Widget build() => buildFrame(buttonKey: buttonKey, value: value, onChanged: onChanged);

    await tester.pumpWidget(build());
    RenderBox buttonBox = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBox.attached);

    // Show the menu.
    await tester.tap(find.byKey(buttonKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    // Tap on item 'one', which must appear over the button.
    await tester.tap(find.byKey(buttonKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // finish the menu animation

    await tester.pumpWidget(build());
    expect(value, equals('one'));
  });

  testWidgets('Size of DropdownButton with null value and a hint', (WidgetTester tester) async {
    Key buttonKey = new UniqueKey();
    String value;

    // The hint will define the dropdown's width
    Widget build() => buildFrame(buttonKey: buttonKey, value: value, hint: new Text('onetwothree'));

    await tester.pumpWidget(build());
    expect(find.text('onetwothree'), findsOneWidget);
    RenderBox buttonBoxHintValue = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBoxHintValue.attached);


    value = 'three';
    await tester.pumpWidget(build());
    RenderBox buttonBox = tester.renderObject(find.byKey(buttonKey));
    assert(buttonBox.attached);

    // A DropDown button with a null value and a hint should be the same size as a
    // one with a non-null value.
    expect(buttonBox.localToGlobal(Point.origin), equals(buttonBoxHintValue.localToGlobal(Point.origin)));
    expect(buttonBox.size, equals(buttonBoxHintValue.size));
  });

}
