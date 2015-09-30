// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

import 'package:sky/src/fn3/basic.dart';
import 'package:sky/src/fn3/framework.dart';
import 'package:sky/src/fn3/theme.dart';
import 'package:sky/src/rendering/object.dart';
import 'package:sky/src/rendering/toggleable.dart';

export 'package:sky/src/rendering/toggleable.dart' show ValueChanged;

const double _kMidpoint = 0.5;
const sky.Color _kLightUncheckedColor = const sky.Color(0x8A000000);
const sky.Color _kDarkUncheckedColor = const sky.Color(0xB2FFFFFF);
const double _kEdgeSize = 20.0;
const double _kEdgeRadius = 1.0;

/// A material design checkbox
///
/// The checkbox itself does not maintain any state. Instead, when the state of
/// the checkbox changes, the component calls the `onChange` callback. Most
/// components that use a checkbox will listen for the `onChange` callback and
/// rebuild the checkbox with a new `value` to update the visual appearance of
/// the checkbox.
///
/// <https://www.google.com/design/spec/components/lists-controls.html#lists-controls-types-of-list-controls>
class Checkbox extends StatelessComponent {
  /// Constructs a checkbox
  ///
  /// * `value` determines whether the checkbox is checked.
  /// * `onChanged` is called whenever the state of the checkbox should change.
  const Checkbox({Key key, this.value, this.onChanged}) : super(key: key);

  final bool value;
  final ValueChanged onChanged;

  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    Color uncheckedColor = themeData.brightness == ThemeBrightness.light
        ? _kLightUncheckedColor
        : _kDarkUncheckedColor;
    return new _CheckboxWrapper(
      value: value,
      onChanged: onChanged,
      uncheckedColor: uncheckedColor,
      accentColor: themeData.accentColor
    );
  }
}

// This wrapper class exists only because Switch needs to be a Component in
// order to get an accent color from a Theme but Components do not know how to
// host RenderObjects.
class _CheckboxWrapper extends LeafRenderObjectWidget {
  _CheckboxWrapper({
    Key key,
    this.value,
    this.onChanged,
    this.uncheckedColor,
    this.accentColor
  }): super(key: key) {
    assert(uncheckedColor != null);
    assert(accentColor != null);
  }

  final bool value;
  final ValueChanged onChanged;
  final Color uncheckedColor;
  final Color accentColor;

  _RenderCheckbox createRenderObject() => new _RenderCheckbox(
    value: value,
    accentColor: accentColor,
    uncheckedColor: uncheckedColor,
    onChanged: onChanged
  );

  void updateRenderObject(_RenderCheckbox renderObject, _CheckboxWrapper oldWidget) {
    renderObject.value = value;
    renderObject.onChanged = onChanged;
    renderObject.uncheckedColor = uncheckedColor;
    renderObject.accentColor = accentColor;
  }
}

class _RenderCheckbox extends RenderToggleable {
  _RenderCheckbox({
    bool value,
    Color uncheckedColor,
    Color accentColor,
    ValueChanged onChanged
  }): _uncheckedColor = uncheckedColor,
      _accentColor = accentColor,
      super(
        value: value,
        onChanged: onChanged,
        size: new Size(_kEdgeSize, _kEdgeSize)
      ) {
    assert(uncheckedColor != null);
    assert(accentColor != null);
  }

  Color _uncheckedColor;
  Color get uncheckedColor => _uncheckedColor;

  void set uncheckedColor(Color value) {
    assert(value != null);
    if (value == _uncheckedColor)
      return;
    _uncheckedColor = value;
    markNeedsPaint();
  }

  Color _accentColor;
  void set accentColor(Color value) {
    assert(value != null);
    if (value == _accentColor)
      return;
    _accentColor = value;
    markNeedsPaint();
  }

  void paint(PaintingContext context, Offset offset) {
    final PaintingCanvas canvas = context.canvas;
    // Choose a color between grey and the theme color
    sky.Paint paint = new sky.Paint()
      ..strokeWidth = 2.0
      ..color = uncheckedColor;

    // The rrect contracts slightly during the animation
    double inset = 2.0 - (position - _kMidpoint).abs() * 2.0;
    sky.Rect rect = new sky.Rect.fromLTWH(offset.dx + inset, offset.dy + inset,
        _kEdgeSize - inset, _kEdgeSize - inset);
    sky.RRect rrect = new sky.RRect()
      ..setRectXY(rect, _kEdgeRadius, _kEdgeRadius);

    // Outline of the empty rrect
    paint.setStyle(sky.PaintingStyle.stroke);
    canvas.drawRRect(rrect, paint);

    // Radial gradient that changes size
    if (position > 0) {
      paint.setStyle(sky.PaintingStyle.fill);
      paint.setShader(new sky.Gradient.radial(
          new Point(_kEdgeSize / 2.0, _kEdgeSize / 2.0),
          _kEdgeSize * (_kMidpoint - position) * 8.0, [
        const sky.Color(0x00000000),
        uncheckedColor
      ]));
      canvas.drawRRect(rrect, paint);
    }

    if (position > _kMidpoint) {
      double t = (position - _kMidpoint) / (1.0 - _kMidpoint);

      // Solid filled rrect
      paint.setStyle(sky.PaintingStyle.strokeAndFill);
      paint.color = new Color.fromARGB((t * 255).floor(), _accentColor.red,
          _accentColor.green, _accentColor.blue);
      canvas.drawRRect(rrect, paint);

      // White inner check
      paint.color = const sky.Color(0xFFFFFFFF);
      paint.setStyle(sky.PaintingStyle.stroke);
      sky.Path path = new sky.Path();
      sky.Point start = new sky.Point(_kEdgeSize * 0.2, _kEdgeSize * 0.5);
      sky.Point mid = new sky.Point(_kEdgeSize * 0.4, _kEdgeSize * 0.7);
      sky.Point end = new sky.Point(_kEdgeSize * 0.8, _kEdgeSize * 0.3);
      Point lerp(Point p1, Point p2, double t) =>
          new Point(p1.x * (1.0 - t) + p2.x * t, p1.y * (1.0 - t) + p2.y * t);
      sky.Point drawStart = lerp(start, mid, 1.0 - t);
      sky.Point drawEnd = lerp(mid, end, t);
      path.moveTo(offset.dx + drawStart.x, offset.dy + drawStart.y);
      path.lineTo(offset.dx + mid.x, offset.dy + mid.y);
      path.lineTo(offset.dx + drawEnd.x, offset.dy + drawEnd.y);
      canvas.drawPath(path, paint);
    }
  }
}
