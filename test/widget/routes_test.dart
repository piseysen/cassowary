// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

final List<String> results = <String>[];

Set<TestRoute> routes = new HashSet<TestRoute>();

class TestRoute extends Route<String> {
  TestRoute(this.name);
  final String name;

  @override
  List<OverlayEntry> get overlayEntries => _entries;

  List<OverlayEntry> _entries = <OverlayEntry>[];

  void log(String s) {
    results.add('$name: $s');
  }

  @override
  void install(OverlayEntry insertionPoint) {
    log('install');
    OverlayEntry entry = new OverlayEntry(
      builder: (BuildContext context) => new Container(),
      opaque: true
    );
    _entries.add(entry);
    navigator.overlay?.insert(entry, above: insertionPoint);
    routes.add(this);
  }

  @override
  void didPush() {
    log('didPush');
  }

  @override
  void didReplace(TestRoute oldRoute) {
    log('didReplace ${oldRoute.name}');
  }

  @override
  bool didPop(String result) {
    log('didPop $result');
    bool returnValue;
    if (returnValue = super.didPop(result))
      dispose();
    return returnValue;
  }

  @override
  void didPopNext(TestRoute nextRoute) {
    log('didPopNext ${nextRoute.name}');
  }

  @override
  void didChangeNext(TestRoute nextRoute) {
    log('didChangeNext ${nextRoute?.name}');
  }

  @override
  void dispose() {
    log('dispose');
    _entries.forEach((OverlayEntry entry) { entry.remove(); });
    _entries.clear();
    routes.remove(this);
  }

}

void runNavigatorTest(
  WidgetTester tester,
  NavigatorState host,
  NavigatorTransactionCallback test,
  List<String> expectations
) {
  expect(host, isNotNull);
  host.openTransaction(test);
  expect(results, equals(expectations));
  results.clear();
  tester.pump();
}

void main() {
  testWidgets('Route management - push, replace, pop', (WidgetTester tester) {
    GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
    tester.pumpWidget(new Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => new TestRoute('initial')
    ));
    NavigatorState host = navigatorKey.currentState;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
      },
      <String>[
        'initial: install',
        'initial: didPush',
        'initial: didChangeNext null',
      ]
    );
    TestRoute second;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(second = new TestRoute('second'));
      },
      <String>[
        'second: install',
        'second: didPush',
        'second: didChangeNext null',
        'initial: didChangeNext second',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(new TestRoute('third'));
      },
      <String>[
        'third: install',
        'third: didPush',
        'third: didChangeNext null',
        'second: didChangeNext third',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.replace(oldRoute: second, newRoute: new TestRoute('two'));
      },
      <String>[
        'two: install',
        'two: didReplace second',
        'two: didChangeNext third',
        'initial: didChangeNext two',
        'second: dispose',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.pop('hello');
      },
      <String>[
        'third: didPop hello',
        'third: dispose',
        'two: didPopNext third',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.pop('good bye');
      },
      <String>[
        'two: didPop good bye',
        'two: dispose',
        'initial: didPopNext two',
      ]
    );
    tester.pumpWidget(new Container());
    expect(results, equals(<String>['initial: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  testWidgets('Route management - push, remove, pop', (WidgetTester tester) {
    GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
    tester.pumpWidget(new Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => new TestRoute('first')
    ));
    NavigatorState host = navigatorKey.currentState;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
      },
      <String>[
        'first: install',
        'first: didPush',
        'first: didChangeNext null',
      ]
    );
    TestRoute second;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(second = new TestRoute('second'));
      },
      <String>[
        'second: install',
        'second: didPush',
        'second: didChangeNext null',
        'first: didChangeNext second',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(new TestRoute('third'));
      },
      <String>[
        'third: install',
        'third: didPush',
        'third: didChangeNext null',
        'second: didChangeNext third',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.removeRouteBefore(second);
      },
      <String>[
        'first: dispose',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.pop('good bye');
      },
      <String>[
        'third: didPop good bye',
        'third: dispose',
        'second: didPopNext third',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(new TestRoute('three'));
      },
      <String>[
        'three: install',
        'three: didPush',
        'three: didChangeNext null',
        'second: didChangeNext three',
      ]
    );
    TestRoute four;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(four = new TestRoute('four'));
      },
      <String>[
        'four: install',
        'four: didPush',
        'four: didChangeNext null',
        'three: didChangeNext four',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.removeRouteBefore(four);
      },
      <String>[
        'second: didChangeNext four',
        'three: dispose',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.pop('the end');
      },
      <String>[
        'four: didPop the end',
        'four: dispose',
        'second: didPopNext four',
      ]
    );
    tester.pumpWidget(new Container());
    expect(results, equals(<String>['second: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });

  testWidgets('Route management - push, replace, popUntil', (WidgetTester tester) {
    GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
    tester.pumpWidget(new Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => new TestRoute('A')
    ));
    NavigatorState host = navigatorKey.currentState;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
      },
      <String>[
        'A: install',
        'A: didPush',
        'A: didChangeNext null',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(new TestRoute('B'));
      },
      <String>[
        'B: install',
        'B: didPush',
        'B: didChangeNext null',
        'A: didChangeNext B',
      ]
    );
    TestRoute routeC;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.push(routeC = new TestRoute('C'));
      },
      <String>[
        'C: install',
        'C: didPush',
        'C: didChangeNext null',
        'B: didChangeNext C',
      ]
    );
    TestRoute routeB;
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.replaceRouteBefore(anchorRoute: routeC, newRoute: routeB = new TestRoute('b'));
      },
      <String>[
        'b: install',
        'b: didReplace B',
        'b: didChangeNext C',
        'A: didChangeNext b',
        'B: dispose',
      ]
    );
    runNavigatorTest(
      tester,
      host,
      (NavigatorTransaction transaction) {
        transaction.popUntil(routeB);
      },
      <String>[
        'C: didPop null',
        'C: dispose',
        'b: didPopNext C',
      ]
    );
    tester.pumpWidget(new Container());
    expect(results, equals(<String>['A: dispose', 'b: dispose']));
    expect(routes.isEmpty, isTrue);
    results.clear();
  });
}
