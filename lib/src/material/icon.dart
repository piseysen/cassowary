// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'icons.dart';
import 'icon_theme.dart';
import 'theme.dart';

/// A material design icon.
///
/// Available icons are shown on this page:
/// <https://design.google.com/icons/>
///
/// Icons are identified by their name (as given on that page), with
/// spaces converted to underscores, from the [Icons] class. For
/// example, the "alarm add" icon is [Icons.alarm_add].
///
/// To use this class, make sure you set `uses-material-design: true`
/// in your project's `flutter.yaml` file. This ensures that the
/// MaterialIcons font is included in your application. This font is
/// used to display the icons.
class Icon extends StatelessComponent {
  Icon({
    Key key,
    this.icon,
    this.size: 24.0,
    this.color
  }) : super(key: key) {
    assert(size != null);
  }

  /// The size of the icon in logical pixels.
  ///
  /// Icons occupy a square with width and height equal to size.
  final double size;

  /// The icon to display.
  final IconData icon;

  /// The color to use when drawing the icon.
  final Color color;

  Color _getDefaultColorForThemeBrightness(ThemeBrightness brightness) {
    switch (brightness) {
      case ThemeBrightness.dark:
        return Colors.white;
      case ThemeBrightness.light:
        return Colors.black;
    }
  }

  Color _getDefaultColor(BuildContext context) {
    return IconTheme.of(context)?.color ?? _getDefaultColorForThemeBrightness(Theme.of(context).brightness);
  }

  Widget build(BuildContext context) {
    if (icon == null)
      return new SizedBox(width: size, height: size);

    final double iconOpacity = IconTheme.of(context)?.clampedOpacity ?? 1.0;
    Color iconColor = color ?? _getDefaultColor(context);
    if (iconOpacity != 1.0)
      iconColor = iconColor.withOpacity(iconColor.opacity * iconOpacity);

    return new ExcludeSemantics(
      child: new SizedBox(
        width: size,
        height: size,
        child: new Center(
          child: new Text(
            new String.fromCharCode(icon.codePoint),
            style: new TextStyle(
              inherit: false,
              color: iconColor,
              fontSize: size,
              fontFamily: 'MaterialIcons'
            )
          )
        )
      )
    );
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$icon');
    description.add('size: $size');
    if (this.color != null)
      description.add('color: $color');
  }
}
