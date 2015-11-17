// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'material.dart';

const Duration _kBottomSheetDuration = const Duration(milliseconds: 200);
const double _kMinFlingVelocity = 700.0;
const double _kCloseProgressThreshold = 0.5;
const Color _kTransparent = const Color(0x00000000);
const Color _kBarrierColor = Colors.black54;

class _BottomSheetDragController extends StatelessComponent {
  _BottomSheetDragController({
    Key key,
    this.performance,
    this.child,
    this.childHeight
  }) : super(key: key);

  final Performance performance;
  final Widget child;
  final double childHeight;

  bool get _dismissUnderway => performance.direction == AnimationDirection.reverse;

  void _handleDragUpdate(double delta) {
    if (_dismissUnderway)
      return;
    performance.progress -= delta / (childHeight ?? delta);
  }

  void _handleDragEnd(Offset velocity, BuildContext context) {
    if (_dismissUnderway)
      return;
    if (velocity.dy > _kMinFlingVelocity) {
      performance.fling(velocity: -velocity.dy / childHeight).then((_) {
        Navigator.of(context).pop();
      });
    } else if (performance.progress < _kCloseProgressThreshold) {
      performance.fling(velocity: -1.0).then((_) {
        Navigator.of(context).pop();
      });
    } else {
      performance.forward();
    }
  }

  Widget build(BuildContext context) {
    return new GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: (Offset velocity) { _handleDragEnd(velocity, context); },
      child: child
    );
  }
}

class _BottomSheetRoute extends OverlayRoute {
  _BottomSheetRoute({ this.completer, this.child });

  final Completer completer;
  final Widget child;
  Performance performance;

  void didPush(OverlayState overlay, OverlayEntry insertionPoint) {
    performance = new Performance(duration: _kBottomSheetDuration, debugLabel: debugLabel)
      ..forward();
    super.didPush(overlay, insertionPoint);
  }

  void didPop(dynamic result) {
    void finish() {
      super.didPop(result); // clear the overlay entries
      completer.complete(result);
    }
    if (performance.isDismissed)
      finish();
    else
      performance.reverse().then((_) { finish(); });
  }

  String get debugLabel => '$runtimeType';
  String toString() => '$runtimeType(performance: $performance)';
}

class _ModalBottomSheet extends StatefulComponent {
  _ModalBottomSheet({ Key key, this.route }) : super(key: key);

  final _ModalBottomSheetRoute route;

  _ModalBottomSheetState createState() => new _ModalBottomSheetState();
}

class _ModalBottomSheetLayout extends OneChildLayoutDelegate {
  // The distance from the bottom of the parent to the top of the BottomSheet child.
  AnimatedValue<double> childTop = new AnimatedValue<double>(0.0);

  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: 0.0,
      maxHeight: constraints.maxHeight * 9.0 / 16.0
    );
  }

  Point getPositionForChild(Size size, Size childSize) {
    childTop.end = childSize.height;
    return new Point(0.0, size.height - childTop.value);
  }
}

class _ModalBottomSheetState extends State<_ModalBottomSheet> {

  final _ModalBottomSheetLayout _layout = new _ModalBottomSheetLayout();

  Widget build(BuildContext context) {
    return new GestureDetector(
      onTap: () { Navigator.of(context).pop(); },
      child: new BuilderTransition(
        performance: config.route.performance,
        variables: <AnimatedValue<double>>[_layout.childTop],
        builder: (BuildContext context) {
          return new ClipRect(
            child: new CustomOneChildLayout(
              delegate: _layout,
              token: _layout.childTop.value,
              child: new _BottomSheetDragController(
                performance: config.route.performance,
                child: new Material(child: config.route.child),
                childHeight: _layout.childTop.end
              )
            )
          );
        }
      )
    );
  }
}

class _ModalBottomSheetRoute extends _BottomSheetRoute {
  _ModalBottomSheetRoute({ Completer completer, Widget child })
    : super(completer: completer, child: child);

  Widget _buildModalBarrier(BuildContext context) {
    return new AnimatedModalBarrier(
      color: new AnimatedColorValue(_kTransparent, end: _kBarrierColor, curve: Curves.ease),
      performance: performance
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return new Focus(
      key: new GlobalObjectKey(this),
      child: new _ModalBottomSheet(route: this)
    );
  }

  List<WidgetBuilder> get builders => <WidgetBuilder>[
    _buildModalBarrier,
    _buildBottomSheet,
  ];
}

Future showModalBottomSheet({ BuildContext context, Widget child }) {
  assert(child != null);
  final Completer completer = new Completer();
  Navigator.of(context).pushEphemeral(new _ModalBottomSheetRoute(
    completer: completer,
    child: child
  ));
  return completer.future;
}

class _PersistentBottomSheet extends StatefulComponent {
  _PersistentBottomSheet({ Key key, this.route }) : super(key: key);

  final _BottomSheetRoute route;

  _PersistentBottomSheetState createState() => new _PersistentBottomSheetState();
}

class _PersistentBottomSheetState extends State<_PersistentBottomSheet> {

  double _childHeight;
  void _updateChildHeight(Size newSize) {
    setState(() {
      _childHeight = newSize.height;
    });
  }

  Widget build(BuildContext context) {
    return new AlignTransition(
      performance: config.route.performance,
      alignment: new AnimatedValue<FractionalOffset>(const FractionalOffset(0.0, 0.0)),
      heightFactor: new AnimatedValue<double>(0.0, end: 1.0),
      child: new _BottomSheetDragController(
        performance: config.route.performance,
        childHeight: _childHeight,
        child: new Material(
          child: new SizeObserver(child: config.route.child, onSizeChanged: _updateChildHeight)
        )
      )
    );
  }
}

Future showBottomSheet({ BuildContext context, GlobalKey<PlaceholderState> placeholderKey, Widget child }) {
  assert(child != null);
  assert(placeholderKey != null);
  final Completer completer = new Completer();
  _BottomSheetRoute route = new _BottomSheetRoute(child: child, completer: completer);
  placeholderKey.currentState.child = new _PersistentBottomSheet(route: route);
  Navigator.of(context).pushEphemeral(route);
  return completer.future.then((_) {
    // If our overlay has been obscured by an opaque OverlayEntry then currentState
    // will have been cleared already.
    placeholderKey.currentState?.child = null;
  });
}
