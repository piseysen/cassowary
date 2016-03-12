// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

class _MaterialPageTransition extends AnimatedWidget {
  _MaterialPageTransition({
    Key key,
    Animation<double> animation,
    this.child
  }) : super(
    key: key,
    animation: new CurvedAnimation(parent: animation, curve: Curves.easeOut)
  );

  final Widget child;

  final Tween<Point> _position = new Tween<Point>(
    begin: const Point(0.0, 75.0),
    end: Point.origin
  );

  Widget build(BuildContext context) {
    Point position = _position.evaluate(animation);
    Matrix4 transform = new Matrix4.identity()
      ..translate(position.x, position.y);
    return new Transform(
      transform: transform,
      // TODO(ianh): tell the transform to be un-transformed for hit testing
      child: new Opacity(
        opacity: animation.value,
        child: child
      )
    );
  }
}

const Duration kMaterialPageRouteTransitionDuration = const Duration(milliseconds: 150);

class MaterialPageRoute<T> extends PageRoute<T> {
  MaterialPageRoute({
    this.builder,
    Completer<T> completer,
    RouteSettings settings: const RouteSettings()
  }) : super(completer: completer, settings: settings) {
    assert(builder != null);
    assert(opaque);
  }

  final WidgetBuilder builder;

  Duration get transitionDuration => kMaterialPageRouteTransitionDuration;
  Color get barrierColor => null;
  bool canTransitionFrom(TransitionRoute<dynamic> nextRoute) => false;

  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation) {
    Widget result = builder(context);
    assert(() {
      if (result == null)
        debugPrint('The builder for route \'${settings.name}\' returned null. Route builders must never return null.');
      assert(result != null && 'A route builder returned null. See the previous log message for details.' is String);
      return true;
    });
    return result;
  }

  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation, Widget child) {
    return new _MaterialPageTransition(
      animation: animation,
      child: child
    );
  }

  String get debugLabel => '${super.debugLabel}(${settings.name})';
}
