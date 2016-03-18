// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'material.dart';

// TODO(eseidel): Draw width should vary based on device size:
// http://www.google.com/design/spec/layout/structure.html#structure-side-nav

// Mobile:
// Width = Screen width − 56 dp
// Maximum width: 320dp
// Maximum width applies only when using a left nav. When using a right nav,
// the panel can cover the full width of the screen.

// Desktop/Tablet:
// Maximum width for a left nav is 400dp.
// The right nav can vary depending on content.

const double _kWidth = 304.0;
const double _kEdgeDragWidth = 20.0;
const double _kMinFlingVelocity = 365.0;
const Duration _kBaseSettleDuration = const Duration(milliseconds: 246);

class Drawer extends StatelessWidget {
  Drawer({
    Key key,
    this.elevation: 16,
    this.child
  }) : super(key: key);

  final int elevation;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new ConstrainedBox(
      constraints: const BoxConstraints.expand(width: _kWidth),
      child: new Material(
        elevation: elevation,
        child: child
      )
    );
  }
}

class DrawerController extends StatefulWidget {
  DrawerController({
    GlobalKey key,
    this.child
  }) : super(key: key);

  final Widget child;

  @override
  DrawerControllerState createState() => new DrawerControllerState();
}

class DrawerControllerState extends State<DrawerController> {
  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(duration: _kBaseSettleDuration)
      ..addListener(_animationChanged)
      ..addStatusListener(_animationStatusChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_animationChanged)
      ..removeStatusListener(_animationStatusChanged)
      ..stop();
    super.dispose();
  }

  void _animationChanged() {
    setState(() {
      // The animation controller's state is our build state, and it changed already.
    });
  }

  LocalHistoryEntry _historyEntry;
  // TODO(abarth): This should be a GlobalValueKey when those exist.
  GlobalKey get _drawerKey => new GlobalObjectKey(config.key);

  void _ensureHistoryEntry() {
    if (_historyEntry == null) {
      ModalRoute<dynamic> route = ModalRoute.of(context);
      if (route != null) {
        _historyEntry = new LocalHistoryEntry(onRemove: _handleHistoryEntryRemoved);
        route.addLocalHistoryEntry(_historyEntry);
        Focus.moveScopeTo(_drawerKey, context: context);
      }
    }
  }

  void _animationStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _ensureHistoryEntry();
        break;
      case AnimationStatus.reverse:
        _historyEntry?.remove();
        _historyEntry = null;
        break;
      case AnimationStatus.dismissed:
        break;
      case AnimationStatus.completed:
        break;
    }
  }

  void _handleHistoryEntryRemoved() {
    _historyEntry = null;
    close();
  }

  AnimationController _controller;

  void _handleDragDown(Point position) {
    _controller.stop();
    _ensureHistoryEntry();
  }

  void _handleDragCancel() {
    if (_controller.isDismissed || _controller.isAnimating)
      return;
    if (_controller.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  double get _width {
    assert(!Scheduler.debugInFrame); // we should never try to read the tree state while building or laying out
    RenderBox drawerBox = _drawerKey.currentContext?.findRenderObject();
    if (drawerBox != null)
      return drawerBox.size.width;
    return _kWidth; // drawer not being shown currently
  }

  void _move(double delta) {
    _controller.value += delta / _width;
  }

  void _settle(Velocity velocity) {
    if (_controller.isDismissed)
      return;
    if (velocity.pixelsPerSecond.dx.abs() >= _kMinFlingVelocity) {
      _controller.fling(velocity: velocity.pixelsPerSecond.dx / _width);
    } else if (_controller.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  void open() {
    _controller.fling(velocity: 1.0);
  }

  void close() {
    _controller.fling(velocity: -1.0);
  }

  final ColorTween _color = new ColorTween(begin: Colors.transparent, end: Colors.black54);
  final GlobalKey _gestureDetectorKey = new GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (_controller.status == AnimationStatus.dismissed) {
      return new Align(
        alignment: const FractionalOffset(0.0, 0.5),
        child: new GestureDetector(
          key: _gestureDetectorKey,
          onHorizontalDragUpdate: _move,
          onHorizontalDragEnd: _settle,
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          child: new Container(width: _kEdgeDragWidth)
        )
      );
    } else {
      return new GestureDetector(
        key: _gestureDetectorKey,
        onHorizontalDragDown: _handleDragDown,
        onHorizontalDragUpdate: _move,
        onHorizontalDragEnd: _settle,
        onHorizontalDragCancel: _handleDragCancel,
        child: new RepaintBoundary(
          child: new Stack(
            children: <Widget>[
              new GestureDetector(
                onTap: close,
                child: new DecoratedBox(
                  decoration: new BoxDecoration(
                    backgroundColor: _color.evaluate(_controller)
                  ),
                  child: new Container()
                )
              ),
              new Align(
                alignment: const FractionalOffset(0.0, 0.5),
                child: new Align(
                  alignment: const FractionalOffset(1.0, 0.5),
                  widthFactor: _controller.value,
                  child: new RepaintBoundary(
                    child: new Focus(
                      key: _drawerKey,
                      child: config.child
                    )
                  )
                )
              )
            ]
          )
        )
      );
    }
  }
}
