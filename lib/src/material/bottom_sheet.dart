// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'material.dart';

const Duration _kBottomSheetDuration = const Duration(milliseconds: 200);
const double _kMinFlingVelocity = 700.0;
const double _kCloseProgressThreshold = 0.5;
const Color _kTransparent = const Color(0x00000000);
const Color _kBarrierColor = Colors.black54;

class BottomSheet extends StatefulWidget {
  BottomSheet({
    Key key,
    this.animationController,
    this.onClosing,
    this.builder
  }) : super(key: key) {
    assert(onClosing != null);
  }

  /// The animation that controls the bottom sheet's position. The BottomSheet
  /// widget will manipulate the position of this animation, it is not just a
  /// passive observer.
  final AnimationController animationController;
  final VoidCallback onClosing;
  final WidgetBuilder builder;

  @override
  _BottomSheetState createState() => new _BottomSheetState();

  static AnimationController createAnimationController() {
    return new AnimationController(
      duration: _kBottomSheetDuration,
      debugLabel: 'BottomSheet'
    );
  }
}

class _BottomSheetState extends State<BottomSheet> {

  final GlobalKey _childKey = new GlobalKey(debugLabel: 'BottomSheet child');

  double get _childHeight {
    final RenderBox renderBox = _childKey.currentContext.findRenderObject();
    return renderBox.size.height;
  }

  bool get _dismissUnderway => config.animationController.status == AnimationStatus.reverse;

  void _handleDragUpdate(double delta) {
    if (_dismissUnderway)
      return;
    config.animationController.value -= delta / (_childHeight ?? delta);
  }

  void _handleDragEnd(Velocity velocity) {
    if (_dismissUnderway)
      return;
    if (velocity.pixelsPerSecond.dy > _kMinFlingVelocity) {
      double flingVelocity = -velocity.pixelsPerSecond.dy / _childHeight;
      config.animationController.fling(velocity: flingVelocity);
      if (flingVelocity < 0.0)
        config.onClosing();
    } else if (config.animationController.value < _kCloseProgressThreshold) {
      config.animationController.fling(velocity: -1.0);
      config.onClosing();
    } else {
      config.animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: new Material(
        key: _childKey,
        child: config.builder(context)
      )
    );
  }
}

// PERSISTENT BOTTOM SHEETS

// See scaffold.dart


// MODAL BOTTOM SHEETS

class _ModalBottomSheetLayout extends SingleChildLayoutDelegate {
  _ModalBottomSheetLayout(this.progress);

  final double progress;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: 0.0,
      maxHeight: constraints.maxHeight * 9.0 / 16.0
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return new Offset(0.0, size.height - childSize.height * progress);
  }

  @override
  bool shouldRelayout(_ModalBottomSheetLayout oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _ModalBottomSheet<T> extends StatefulWidget {
  _ModalBottomSheet({ Key key, this.route }) : super(key: key);

  final _ModalBottomSheetRoute<T> route;

  @override
  _ModalBottomSheetState<T> createState() => new _ModalBottomSheetState<T>();
}

class _ModalBottomSheetState<T> extends State<_ModalBottomSheet<T>> {
  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      onTap: () => Navigator.pop(context),
      child: new AnimatedBuilder(
        animation: config.route.animation,
        builder: (BuildContext context, Widget child) {
          return new ClipRect(
            child: new CustomSingleChildLayout(
              delegate: new _ModalBottomSheetLayout(config.route.animation.value),
              child: new BottomSheet(
                animationController: config.route.animation,
                onClosing: () => Navigator.pop(context),
                builder: config.route.builder
              )
            )
          );
        }
      )
    );
  }
}

class _ModalBottomSheetRoute<T> extends PopupRoute<T> {
  _ModalBottomSheetRoute({
    Completer<T> completer,
    this.builder
  }) : super(completer: completer);

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => _kBottomSheetDuration;

  @override
  bool get barrierDismissable => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  AnimationController createAnimationController() {
    return BottomSheet.createAnimationController();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation) {
    return new _ModalBottomSheet<T>(route: this);
  }
}

Future<dynamic/*=T*/> showModalBottomSheet/*<T>*/({ BuildContext context, WidgetBuilder builder }) {
  assert(context != null);
  assert(builder != null);
  final Completer<dynamic/*=T*/> completer = new Completer<dynamic/*=T*/>();
  Navigator.push(context, new _ModalBottomSheetRoute<dynamic/*=T*/>(
    completer: completer,
    builder: builder
  ));
  return completer.future;
}
