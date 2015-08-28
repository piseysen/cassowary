// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:sky/animation/animated_value.dart';
import 'package:sky/animation/animation_performance.dart';
import 'package:sky/animation/curves.dart';
import 'package:sky/painting/text_style.dart';
import 'package:sky/theme/typography.dart' as typography;
import 'package:sky/widgets/basic.dart';
import 'package:sky/widgets/default_text_style.dart';
import 'package:sky/widgets/gesture_detector.dart';
import 'package:sky/widgets/material.dart';
import 'package:sky/widgets/theme.dart';
import 'package:sky/widgets/transitions.dart';

export 'package:sky/animation/animation_performance.dart' show AnimationStatus;

typedef void SnackBarDismissedCallback();

const Duration _kSlideInDuration = const Duration(milliseconds: 200);

class SnackBarAction extends Component {
  SnackBarAction({Key key, this.label, this.onPressed }) : super(key: key) {
    assert(label != null);
  }

  final String label;
  final Function onPressed;

  Widget build() {
    return new GestureDetector(
      onTap: onPressed,
      child: new Container(
        margin: const EdgeDims.only(left: 24.0),
        padding: const EdgeDims.only(top: 14.0, bottom: 14.0),
        child: new Text(label)
      )
    );
  }
}

class SnackBar extends Component {

  SnackBar({
    Key key,
    this.anchor,
    this.content,
    this.actions,
    this.showing,
    this.onDismissed
  }) : super(key: key) {
    assert(content != null);
  }

  Anchor anchor;
  Widget content;
  List<SnackBarAction> actions;
  bool showing;
  SnackBarDismissedCallback onDismissed;

  Widget build() {
    List<Widget> children = [
      new Flexible(
        child: new Container(
          margin: const EdgeDims.symmetric(vertical: 14.0),
          child: new DefaultTextStyle(
            style: typography.white.subhead,
            child: content
          )
        )
      )
    ];
    if (actions != null)
      children.addAll(actions);

    return new SlideTransition(
      duration: _kSlideInDuration,
      direction: showing ? Direction.forward : Direction.reverse,
      position: new AnimatedValue<Point>(Point.origin,
                                         end: const Point(0.0, -52.0),
                                         curve: easeIn, reverseCurve: easeOut),
      onDismissed: onDismissed,
      anchor: anchor,
      child: new Material(
        level: 2,
        color: const Color(0xFF323232),
        type: MaterialType.canvas,
        child: new Container(
          margin: const EdgeDims.symmetric(horizontal: 24.0),
          child: new DefaultTextStyle(
            style: new TextStyle(color: Theme.of(this).accentColor),
            child: new Row(children)
          )
        )
      )
    );
  }
}
