// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

import 'package:sky/src/rendering/object.dart';
import 'package:sky/src/widgets/basic.dart';
import 'package:sky/src/widgets/button_base.dart';
import 'package:sky/src/widgets/framework.dart';
import 'package:sky/src/widgets/gesture_detector.dart';
import 'package:sky/src/widgets/theme.dart';

const sky.Color _kLightOffColor = const sky.Color(0x8A000000);
const sky.Color _kDarkOffColor = const sky.Color(0xB2FFFFFF);

typedef RadioValueChanged(Object value);

class Radio extends ButtonBase {

  Radio({
    Key key,
    this.value,
    this.groupValue,
    this.onChanged
  }) : super(key: key) {
    assert(onChanged != null);
  }

  Object value;
  Object groupValue;
  RadioValueChanged onChanged;

  void syncConstructorArguments(Radio source) {
    value = source.value;
    groupValue = source.groupValue;
    onChanged = source.onChanged;
    super.syncConstructorArguments(source);
  }

  Color get color {
    ThemeData themeData = Theme.of(this);
    if (value == groupValue)
      return themeData.accentColor;
    return themeData.brightness == ThemeBrightness.light ? _kLightOffColor : _kDarkOffColor;
  }

  Widget buildContent() {
    const double kDiameter = 16.0;
    const double kOuterRadius = kDiameter / 2;
    const double kInnerRadius = 5.0;
    return new GestureDetector(
      onTap: () => onChanged(value),
      child: new Container(
        margin: const EdgeDims.symmetric(horizontal: 5.0),
        width: kDiameter,
        height: kDiameter,
        child: new CustomPaint(
          callback: (sky.Canvas canvas, Size size) {

            Paint paint = new Paint()..color = color;

            // Draw the outer circle
            paint.setStyle(sky.PaintingStyle.stroke);
            paint.strokeWidth = 2.0;
            canvas.drawCircle(const Point(kOuterRadius, kOuterRadius), kOuterRadius, paint);

            // Draw the inner circle
            if (value == groupValue) {
              paint.setStyle(sky.PaintingStyle.fill);
              canvas.drawCircle(const Point(kOuterRadius, kOuterRadius), kInnerRadius, paint);
            }
          }
        )
      )
    );
  }

}
