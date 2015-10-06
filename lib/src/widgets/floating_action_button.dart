// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/gestures.dart';
import 'package:sky/src/widgets/basic.dart';
import 'package:sky/src/widgets/button_state.dart';
import 'package:sky/src/widgets/framework.dart';
import 'package:sky/src/widgets/icon.dart';
import 'package:sky/src/widgets/ink_well.dart';
import 'package:sky/src/widgets/material.dart';
import 'package:sky/src/widgets/theme.dart';

// TODO(eseidel): This needs to change based on device size?
// http://www.google.com/design/spec/layout/metrics-keylines.html#metrics-keylines-keylines-spacing
const double _kSize = 56.0;

class FloatingActionButton extends StatefulComponent {
  const FloatingActionButton({
    Key key,
    this.child,
    this.backgroundColor,
    this.onPressed
  }) : super(key: key);

  final Widget child;
  final Color backgroundColor;
  final GestureTapCallback onPressed;

  _FloatingActionButtonState createState() => new _FloatingActionButtonState();
}

class _FloatingActionButtonState extends ButtonState<FloatingActionButton> {
  Widget buildContent(BuildContext context) {
    IconThemeColor iconThemeColor = IconThemeColor.white;
    Color materialColor = config.backgroundColor;
    if (materialColor == null) {
      ThemeData themeData = Theme.of(context);
      materialColor = themeData.accentColor;
      iconThemeColor = themeData.accentColorBrightness == ThemeBrightness.dark ? IconThemeColor.white : IconThemeColor.black;
    }

    return new Material(
      color: materialColor,
      type: MaterialType.circle,
      level: highlight ? 3 : 2,
      child: new ClipOval(
        child: new Container(
          width: _kSize,
          height: _kSize,
          child: new InkWell(
            onTap: config.onPressed,
            child: new Center(
              child: new IconTheme(
                data: new IconThemeData(color: iconThemeColor),
                child: config.child
              )
            )
          )
        )
      )
    );
  }
}
