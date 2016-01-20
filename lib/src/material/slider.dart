// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'constants.dart';
import 'debug.dart';
import 'theme.dart';

class Slider extends StatelessComponent {
  Slider({
    Key key,
    this.value,
    this.min: 0.0,
    this.max: 1.0,
    this.activeColor,
    this.onChanged
  }) : super(key: key) {
    assert(value != null);
    assert(min != null);
    assert(max != null);
    assert(value >= min && value <= max);
  }

  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  void _handleChanged(double value) {
    assert(onChanged != null);
    onChanged(value * (max - min) + min);
  }

  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    return new _SliderRenderObjectWidget(
      value: (value - min) / (max - min),
      activeColor: activeColor ?? Theme.of(context).accentColor,
      onChanged: onChanged != null ? _handleChanged : null
    );
  }
}

class _SliderRenderObjectWidget extends LeafRenderObjectWidget {
  _SliderRenderObjectWidget({ Key key, this.value, this.activeColor, this.onChanged })
      : super(key: key);

  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  _RenderSlider createRenderObject() => new _RenderSlider(
    value: value,
    activeColor: activeColor,
    onChanged: onChanged
  );

  void updateRenderObject(_RenderSlider renderObject, _SliderRenderObjectWidget oldWidget) {
    renderObject.value = value;
    renderObject.activeColor = activeColor;
    renderObject.onChanged = onChanged;
  }
}

const double _kThumbRadius = 6.0;
const double _kThumbRadiusDisabled = 3.0;
const double _kReactionRadius = 16.0;
const double _kTrackWidth = 144.0;
final Color _kInactiveTrackColor = Colors.grey[400];
final Color _kActiveTrackColor = Colors.grey[500];

class _RenderSlider extends RenderConstrainedBox {
  _RenderSlider({
    double value,
    Color activeColor,
    this.onChanged
  }) : _value = value,
       _activeColor = activeColor,
        super(additionalConstraints: const BoxConstraints.tightFor(width: _kTrackWidth + 2 * _kReactionRadius, height: 2 * _kReactionRadius)) {
    assert(value != null && value >= 0.0 && value <= 1.0);
    _drag = new HorizontalDragGestureRecognizer(router: Gesturer.instance.pointerRouter, gestureArena: Gesturer.instance.gestureArena)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd;
    _reactionController = new AnimationController(duration: kRadialReactionDuration);
    _reaction = new Tween<double>(
      begin: _kThumbRadius,
      end: _kReactionRadius
    ).animate(new CurvedAnimation(
      parent: _reactionController,
      curve: Curves.ease
    ))..addListener(markNeedsPaint);
  }

  double get value => _value;
  double _value;
  void set value(double newValue) {
    assert(newValue != null && newValue >= 0.0 && newValue <= 1.0);
    if (newValue == _value)
      return;
    _value = newValue;
    markNeedsPaint();
  }

  Color get activeColor => _activeColor;
  Color _activeColor;
  void set activeColor(Color value) {
    if (value == _activeColor)
      return;
    _activeColor = value;
    markNeedsPaint();
  }

  ValueChanged<double> onChanged;

  double get _trackLength => size.width - 2.0 * _kReactionRadius;

  Animation<double> _reaction;
  AnimationController _reactionController;

  HorizontalDragGestureRecognizer _drag;
  bool _active = false;
  double _currentDragValue = 0.0;

  void _handleDragStart(Point globalPosition) {
    if (onChanged != null) {
      _active = true;
      _currentDragValue = (globalToLocal(globalPosition).x - _kReactionRadius) / _trackLength;
      onChanged(_currentDragValue.clamp(0.0, 1.0));
      _reactionController.forward();
      markNeedsPaint();
    }
  }

  void _handleDragUpdate(double delta) {
    if (onChanged != null) {
      _currentDragValue += delta / _trackLength;
      onChanged(_currentDragValue.clamp(0.0, 1.0));
    }
  }

  void _handleDragEnd(Offset velocity) {
    if (_active) {
      _active = false;
      _currentDragValue = 0.0;
      _reactionController.reverse();
      markNeedsPaint();
    }
  }

  bool hitTestSelf(Point position) => true;

  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent && onChanged != null)
      _drag.addPointer(event);
  }

  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    final double trackLength = _trackLength;
    final bool enabled = onChanged != null;

    double trackCenter = offset.dy + size.height / 2.0;
    double trackLeft = offset.dx + _kReactionRadius;
    double trackTop = trackCenter - 1.0;
    double trackBottom = trackCenter + 1.0;
    double trackRight = trackLeft + trackLength;
    double trackActive = trackLeft + trackLength * value;

    Paint primaryPaint = new Paint()..color = enabled ? _activeColor : _kInactiveTrackColor;
    Paint trackPaint = new Paint()..color = _active ? _kActiveTrackColor : _kInactiveTrackColor;

    double thumbRadius = enabled ? _kThumbRadius : _kThumbRadiusDisabled;

    canvas.drawRect(new Rect.fromLTRB(trackLeft, trackTop, trackRight, trackBottom), trackPaint);
    if (_value > 0.0)
      canvas.drawRect(new Rect.fromLTRB(trackLeft, trackTop, trackActive, trackBottom), primaryPaint);

    Point activeLocation = new Point(trackActive, trackCenter);
    if (_reaction.status != AnimationStatus.dismissed) {
      Paint reactionPaint = new Paint()..color = _activeColor.withAlpha(kRadialReactionAlpha);
      canvas.drawCircle(activeLocation, _reaction.value, reactionPaint);
    }
    canvas.drawCircle(activeLocation, thumbRadius, primaryPaint);
  }
}
