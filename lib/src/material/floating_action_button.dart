// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'icon_theme_data.dart';
import 'icon_theme.dart';
import 'ink_well.dart';
import 'material.dart';
import 'theme.dart';
import 'tooltip.dart';

// TODO(eseidel): This needs to change based on device size?
// http://www.google.com/design/spec/layout/metrics-keylines.html#metrics-keylines-keylines-spacing
const double _kSize = 56.0;
const double _kSizeMini = 40.0;
const Duration _kChildSegue = const Duration(milliseconds: 400);
const Interval _kChildSegueInterval = const Interval(0.65, 1.0);

/// A material design "floating action button".
///
/// A floating action button is a circular icon button that hovers over content
/// to promote a primary action in the application.
///
/// Use at most a single floating action button per screen. Floating action
/// buttons should be used for positive actions such as "create", "share", or
/// "navigate".
///
/// If the [onPressed] callback is not specified or null, then the button will
/// be disabled, will not react to touch.
///
/// See also:
///  * https://www.google.com/design/spec/components/buttons-floating-action-button.html
class FloatingActionButton extends StatefulWidget {
  const FloatingActionButton({
    Key key,
    this.child,
    this.tooltip,
    this.backgroundColor,
    this.elevation: 6,
    this.highlightElevation: 12,
    this.onPressed,
    this.mini: false
  }) : super(key: key);

  final Widget child;
  final String tooltip;
  final Color backgroundColor;

  /// The callback that is invoked when the button is tapped or otherwise activated.
  ///
  /// If this is set to null, the button will be disabled.
  final VoidCallback onPressed;
  final int elevation;
  final int highlightElevation;
  final bool mini;

  _FloatingActionButtonState createState() => new _FloatingActionButtonState();
}

class _FloatingActionButtonState extends State<FloatingActionButton> {
  Animation<double> _childSegue;
  AnimationController _childSegueController;

  void initState() {
    super.initState();
    _childSegueController = new AnimationController(duration: _kChildSegue)
      ..forward();
    _childSegue = new Tween<double>(
      begin: -0.125,
      end: 0.0
    ).animate(new CurvedAnimation(
      parent: _childSegueController,
      curve: _kChildSegueInterval
    ));
  }

  void didUpdateConfig(FloatingActionButton oldConfig) {
    super.didUpdateConfig(oldConfig);
    if (Widget.canUpdate(oldConfig.child, config.child) && config.backgroundColor == oldConfig.backgroundColor)
      return;
    _childSegueController
      ..value = 0.0
      ..forward();
  }

  bool _highlight = false;

  void _handleHighlightChanged(bool value) {
    setState(() {
      _highlight = value;
    });
  }

  Widget build(BuildContext context) {
    Color iconColor = Colors.white;
    Color materialColor = config.backgroundColor;
    if (materialColor == null) {
      ThemeData themeData = Theme.of(context);
      materialColor = themeData.accentColor;
      iconColor = themeData.accentColorBrightness == ThemeBrightness.dark ? Colors.white : Colors.black;
    }

    Widget result = new Center(
      child: new IconTheme(
        data: new IconThemeData(color: iconColor),
        child: new RotationTransition(
          turns: _childSegue,
          child: config.child
        )
      )
    );

    if (config.tooltip != null) {
      result = new Tooltip(
        message: config.tooltip,
        child: result
      );
    }

    return new Material(
      color: materialColor,
      type: MaterialType.circle,
      elevation: _highlight ? config.highlightElevation : config.elevation,
      child: new Container(
        width: config.mini ? _kSizeMini : _kSize,
        height: config.mini ? _kSizeMini : _kSize,
        child: new InkWell(
          onTap: config.onPressed,
          onHighlightChanged: _handleHighlightChanged,
          child: result
        )
      )
    );
  }
}
