// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/material.dart';
import 'package:sky/src/widgets/framework.dart';

export 'package:sky/material.dart' show ThemeData, ThemeBrightness;

class Theme extends InheritedWidget {
  Theme({
    Key key,
    this.data,
    Widget child
  }) : super(key: key, child: child) {
    assert(child != null);
    assert(data != null);
  }

  final ThemeData data;

  static final ThemeData _kFallbackTheme = new ThemeData.fallback();

  static ThemeData of(BuildContext context) {
    Theme theme = context.inheritedWidgetOfType(Theme);
    return theme == null ? _kFallbackTheme : theme.data;
  }

  bool updateShouldNotify(Theme old) => data != old.data;
}
