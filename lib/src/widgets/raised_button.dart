// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/theme/colors.dart' as colors;
import 'package:sky/src/widgets/basic.dart';
import 'package:sky/src/widgets/framework.dart';
import 'package:sky/src/widgets/material_button.dart';
import 'package:sky/src/widgets/theme.dart';

class RaisedButton extends MaterialButton {

  RaisedButton({
    Key key,
    Widget child,
    bool enabled: true,
    Function onPressed
  }) : super(key: key,
             child: child,
             enabled: enabled,
             onPressed: onPressed);

  Color get color {
    if (enabled) {
      switch (Theme.of(this).brightness) {
        case ThemeBrightness.light:
          if (highlight)
            return colors.Grey[350];
          else
            return colors.Grey[300];
          break;
        case ThemeBrightness.dark:
          if (highlight)
            return Theme.of(this).primarySwatch[700];
          else
            return Theme.of(this).primarySwatch[600];
          break;
      }
    } else {
      return colors.Grey[350];
    }
  }

  int get level => enabled ? (highlight ? 2 : 1) : 0;
}
