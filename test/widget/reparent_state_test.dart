// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

class StateMarker extends StatefulWidget {
  StateMarker({ Key key, this.child }) : super(key: key);

  final Widget child;

  @override
  StateMarkerState createState() => new StateMarkerState();
}

class StateMarkerState extends State<StateMarker> {
  String marker;

  @override
  Widget build(BuildContext context) {
    if (config.child != null)
      return config.child;
    return new Container();
  }
}

void main() {
  test('can reparent state', () {
    testWidgets((WidgetTester tester) {
      GlobalKey left = new GlobalKey();
      GlobalKey right = new GlobalKey();

      StateMarker grandchild = new StateMarker();
      tester.pumpWidget(
        new Stack(
          children: <Widget>[
            new Container(
              child: new StateMarker(key: left)
            ),
            new Container(
              child: new StateMarker(
                key: right,
                child: grandchild
              )
            ),
          ]
        )
      );

      StateMarkerState leftState = left.currentState;
      leftState.marker = "left";
      StateMarkerState rightState = right.currentState;
      rightState.marker = "right";

      StateMarkerState grandchildState = tester.findStateByConfig(grandchild);
      expect(grandchildState, isNotNull);
      grandchildState.marker = "grandchild";

      StateMarker newGrandchild = new StateMarker();
      tester.pumpWidget(
        new Stack(
          children: <Widget>[
            new Container(
              child: new StateMarker(
                key: right,
                child: newGrandchild
              )
            ),
            new Container(
              child: new StateMarker(key: left)
            ),
          ]
        )
      );

      expect(left.currentState, equals(leftState));
      expect(leftState.marker, equals("left"));
      expect(right.currentState, equals(rightState));
      expect(rightState.marker, equals("right"));

      StateMarkerState newGrandchildState = tester.findStateByConfig(newGrandchild);
      expect(newGrandchildState, isNotNull);
      expect(newGrandchildState, equals(grandchildState));
      expect(newGrandchildState.marker, equals("grandchild"));

      tester.pumpWidget(
        new Center(
          child: new Container(
            child: new StateMarker(
              key: left,
              child: new Container()
            )
          )
        )
      );

      expect(left.currentState, equals(leftState));
      expect(leftState.marker, equals("left"));
      expect(right.currentState, isNull);
    });
  });

  test('can reparent state with multichild widgets', () {
    testWidgets((WidgetTester tester) {
      GlobalKey left = new GlobalKey();
      GlobalKey right = new GlobalKey();

      StateMarker grandchild = new StateMarker();
      tester.pumpWidget(
        new Stack(
          children: <Widget>[
            new StateMarker(key: left),
            new StateMarker(
              key: right,
              child: grandchild
            )
          ]
        )
      );

      StateMarkerState leftState = left.currentState;
      leftState.marker = "left";
      StateMarkerState rightState = right.currentState;
      rightState.marker = "right";

      StateMarkerState grandchildState = tester.findStateByConfig(grandchild);
      expect(grandchildState, isNotNull);
      grandchildState.marker = "grandchild";

      StateMarker newGrandchild = new StateMarker();
      tester.pumpWidget(
        new Stack(
          children: <Widget>[
            new StateMarker(
              key: right,
              child: newGrandchild
            ),
            new StateMarker(key: left)
          ]
        )
      );

      expect(left.currentState, equals(leftState));
      expect(leftState.marker, equals("left"));
      expect(right.currentState, equals(rightState));
      expect(rightState.marker, equals("right"));

      StateMarkerState newGrandchildState = tester.findStateByConfig(newGrandchild);
      expect(newGrandchildState, isNotNull);
      expect(newGrandchildState, equals(grandchildState));
      expect(newGrandchildState.marker, equals("grandchild"));

      tester.pumpWidget(
        new Center(
          child: new Container(
            child: new StateMarker(
              key: left,
              child: new Container()
            )
          )
        )
      );

      expect(left.currentState, equals(leftState));
      expect(leftState.marker, equals("left"));
      expect(right.currentState, isNull);
    });
  });

  test('can with scrollable list', () {
    testWidgets((WidgetTester tester) {
      GlobalKey key = new GlobalKey();

      tester.pumpWidget(new StateMarker(key: key));

      StateMarkerState keyState = key.currentState;
      keyState.marker = "marked";

      tester.pumpWidget(new ScrollableList(
        itemExtent: 100.0,
        children: <Widget>[
          new Container(
            key: new Key('container'),
            height: 100.0,
            child: new StateMarker(key: key)
          )
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));

      tester.pumpWidget(new StateMarker(key: key));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));
    });
  });

  test('Reparent during update children', () {
    testWidgets((WidgetTester tester) {
      GlobalKey key = new GlobalKey();

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new StateMarker(key: key),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      StateMarkerState keyState = key.currentState;
      keyState.marker = "marked";

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0),
          new StateMarker(key: key),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new StateMarker(key: key),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));
    });
  });

  test('Reparent to child during update children', () {
    testWidgets((WidgetTester tester) {
      GlobalKey key = new GlobalKey();

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0),
          new StateMarker(key: key),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      StateMarkerState keyState = key.currentState;
      keyState.marker = "marked";

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0, child: new StateMarker(key: key)),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0),
          new StateMarker(key: key),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0),
          new Container(width: 100.0, height: 100.0, child: new StateMarker(key: key)),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));

      tester.pumpWidget(new Stack(
        children: <Widget>[
          new Container(width: 100.0, height: 100.0),
          new StateMarker(key: key),
          new Container(width: 100.0, height: 100.0),
        ]
      ));

      expect(key.currentState, equals(keyState));
      expect(keyState.marker, equals("marked"));
    });
  });
}
