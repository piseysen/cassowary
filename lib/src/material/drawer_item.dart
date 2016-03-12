// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'debug.dart';
import 'icon.dart';
import 'icons.dart';
import 'ink_well.dart';
import 'theme.dart';

class DrawerItem extends StatelessWidget {
  const DrawerItem({
    Key key,
    this.icon,
    this.child,
    this.onPressed,
    this.selected: false
  }) : super(key: key);

  final IconData icon;
  final Widget child;
  final VoidCallback onPressed;
  final bool selected;

  Color _getIconColor(ThemeData themeData) {
    switch (themeData.brightness) {
      case ThemeBrightness.light:
        if (selected)
          return themeData.primaryColor;
        if (onPressed == null)
          return Colors.black26;
        return Colors.black45;
      case ThemeBrightness.dark:
        if (selected)
          return themeData.accentColor;
        if (onPressed == null)
          return Colors.white30;
        return null; // use default icon theme colour unmodified
    }
  }

  TextStyle _getTextStyle(ThemeData themeData) {
    TextStyle result = themeData.textTheme.body2;
    if (selected) {
      switch (themeData.brightness) {
        case ThemeBrightness.light:
          return result.copyWith(color: themeData.primaryColor);
        case ThemeBrightness.dark:
          return result.copyWith(color: themeData.accentColor);
      }
    }
    return result;
  }

  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    ThemeData themeData = Theme.of(context);

    List<Widget> children = <Widget>[];
    if (icon != null) {
      children.add(
        new Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: new Icon(
            icon: icon,
            color: _getIconColor(themeData)
          )
        )
      );
    }
    children.add(
      new Flexible(
        child: new Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: new DefaultTextStyle(
            style: _getTextStyle(themeData),
            child: child
          )
        )
      )
    );

    return new MergeSemantics(
      child: new Container(
        height: 48.0,
        child: new InkWell(
          onTap: onPressed,
          child: new Row(children: children)
        )
      )
    );
  }

}
