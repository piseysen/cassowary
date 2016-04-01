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

/// An item in a material design drawer.
///
/// Part of the material design [Drawer].
///
/// Requires one of its ancestors to be a [Material] widget.
///
/// See also:
///
///  * [Drawer]
///  * [DrawerHeader]
///  * <https://www.google.com/design/spec/patterns/navigation-drawer.html>
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    Key key,
    this.icon,
    this.child,
    this.onPressed,
    this.selected: false
  }) : super(key: key);

  /// The icon to display before the child widget.
  final IconData icon;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Called when the user taps this drawer item.
  ///
  /// If null, the drawer item is displayed as disabled.
  final VoidCallback onPressed;

  /// Whether this drawer item is currently selected.
  ///
  /// The currently selected item is highlighted to distinguish it from other
  /// drawer items.
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

  @override
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
