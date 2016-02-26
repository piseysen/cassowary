// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderEditableLine;
import 'package:sky_services/editing/editing.mojom.dart' as mojom;
import 'package:flutter/services.dart';

import 'basic.dart';
import 'framework.dart';
import 'focus.dart';
import 'scrollable.dart';
import 'scroll_behavior.dart';

export 'package:flutter/painting.dart' show TextSelection;
export 'package:sky_services/editing/editing.mojom.dart' show KeyboardType;

const Duration _kCursorBlinkHalfPeriod = const Duration(milliseconds: 500);

TextSelection _getTextSelectionFromEditingState(mojom.EditingState state) {
  return new TextSelection(
    baseOffset: state.selectionBase,
    extentOffset: state.selectionExtent,
    affinity: TextAffinity.values[state.selectionAffinity.mojoEnumValue],
    isDirectional: state.selectionIsDirectional
  );
}

class _KeyboardClientImpl implements mojom.KeyboardClient {
  _KeyboardClientImpl({
    this.inputValue,
    this.onUpdated,
    this.onSubmitted
  }) {
    assert(inputValue != null);
    assert(onUpdated != null);
    assert(onSubmitted != null);
  }

  InputValue inputValue;

  /// Called whenever the text changes.
  final VoidCallback onUpdated;

  /// Called whenever the user indicates they are done editing the string.
  final VoidCallback onSubmitted;

  /// A keyboard client stub that can be attached to a keyboard service.
  mojom.KeyboardClientStub createStub() {
    return new mojom.KeyboardClientStub.unbound()..impl = this;
  }

  mojom.EditingState get editingState {
    return new mojom.EditingState()
      ..text = inputValue.text
      ..selectionBase = inputValue.selection.baseOffset
      ..selectionExtent = inputValue.selection.extentOffset
      ..selectionAffinity = mojom.TextAffinity.values[inputValue.selection.affinity.index]
      ..selectionIsDirectional = inputValue.selection.isDirectional
      ..composingBase = inputValue.composing.start
      ..composingExtent = inputValue.composing.end;
  }

  void updateEditingState(mojom.EditingState state) {
    inputValue = new InputValue(
      text: state.text,
      selection: _getTextSelectionFromEditingState(state),
      composing: new TextRange(start: state.composingBase, end: state.composingExtent)
    );
    onUpdated();
  }

  void clearComposing() {
    inputValue = inputValue.copyWith(composing: TextRange.empty);
  }

  void submit(mojom.SubmitAction action) {
    clearComposing();
    onSubmitted();
  }
}

/// Configurable state of an input field.
class InputValue {
  const InputValue({
    this.text: '',
    this.selection: const TextSelection.collapsed(offset: -1),
    this.composing: TextRange.empty
  });

  /// The current text being edited.
  final String text;

  /// The range of text that is currently selected.
  final TextSelection selection;

  // The range of text that is still being composed.
  final TextRange composing;

  static const InputValue empty = const InputValue();

  String toString() => '$runtimeType(text: $text, selection: $selection, composing: $composing)';

  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (other is! InputValue)
      return false;
    InputValue typedOther = other;
    return typedOther.text == text
        && typedOther.selection == selection
        && typedOther.composing == composing;
  }

  int get hashCode => hashValues(
    text.hashCode,
    selection.hashCode,
    composing.hashCode
  );

  InputValue copyWith({
    String text,
    TextSelection selection,
    TextRange composing
  }) {
    return new InputValue (
      text: text ?? this.text,
      selection: selection ?? this.selection,
      composing: composing ?? this.composing
    );
  }
}

/// A basic single-line input control.
///
/// This control is not intended to be used directly. Instead, consider using
/// [Input], which provides focus management and material design.
class RawInputLine extends Scrollable {
  RawInputLine({
    Key key,
    this.value,
    this.focusKey,
    this.hideText: false,
    this.style,
    this.cursorColor,
    this.selectionColor,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted
  }) : super(
    key: key,
    initialScrollOffset: 0.0,
    scrollDirection: Axis.horizontal
  );

  /// The string being displayed in this widget.
  final InputValue value;

  /// Key of the enclosing widget that holds the focus.
  final GlobalKey focusKey;

  /// Whether to hide the text being edited (e.g., for passwords).
  final bool hideText;

  /// The text style to use for the editable text.
  final TextStyle style;

  /// The color to use when painting the cursor.
  final Color cursorColor;

  /// The color to use when painting the selection.
  final Color selectionColor;

  /// The type of keyboard to use for editing the text.
  final KeyboardType keyboardType;

  /// Called when the text being edited changes.
  final ValueChanged<InputValue> onChanged;

  /// Called when the user indicates that they are done editing the text in the field.
  final ValueChanged<InputValue> onSubmitted;

  RawInputLineState createState() => new RawInputLineState();
}

class RawInputLineState extends ScrollableState<RawInputLine> {
  Timer _cursorTimer;
  bool _showCursor = false;

  _KeyboardClientImpl _keyboardClient;
  KeyboardHandle _keyboardHandle;

  ScrollBehavior createScrollBehavior() => new BoundedBehavior();
  BoundedBehavior get scrollBehavior => super.scrollBehavior;

  void initState() {
    super.initState();
    _keyboardClient = new _KeyboardClientImpl(
      inputValue: config.value,
      onUpdated: _handleTextUpdated,
      onSubmitted: _handleTextSubmitted
    );
  }

  void didUpdateConfig(RawInputLine oldConfig) {
    if (_keyboardClient.inputValue != config.value) {
      _keyboardClient.inputValue = config.value;
      if (_isAttachedToKeyboard) {
        _keyboardHandle.setEditingState(_keyboardClient.editingState);
      }
    }
  }

  bool get _isAttachedToKeyboard => _keyboardHandle != null && _keyboardHandle.attached;

  double _contentWidth = 0.0;
  double _containerWidth = 0.0;

  Offset _handlePaintOffsetUpdateNeeded(ViewportDimensions dimensions) {
    // We make various state changes here but don't have to do so in a
    // setState() callback because we are called during layout and all
    // we're updating is the new offset, which we are providing to the
    // render object via our return value.
    _containerWidth = dimensions.containerSize.width;
    _contentWidth = dimensions.contentSize.width;
    scrollTo(scrollBehavior.updateExtents(
      contentExtent: _contentWidth,
      containerExtent: _containerWidth,
      // Set the scroll offset to match the content width so that the
      // cursor (which is always at the end of the text) will be
      // visible.
      // TODO(ianh): We should really only do this when text is added,
      // not generally any time the size changes.
      scrollOffset: pixelOffsetToScrollOffset(-_contentWidth)
    ));
    updateGestureDetector();
    return scrollOffsetToPixelDelta(scrollOffset);
  }

  void _attachOrDetachKeyboard(bool focused) {
    if (focused && !_isAttachedToKeyboard) {
      _keyboardHandle = keyboard.attach(_keyboardClient.createStub(),
                                        new mojom.KeyboardConfiguration()
                                          ..type = config.keyboardType);
      _keyboardHandle.setEditingState(_keyboardClient.editingState);
      _keyboardHandle.show();
    } else if (!focused && _isAttachedToKeyboard) {
      _keyboardHandle.release();
      _keyboardHandle = null;
      _keyboardClient.clearComposing();
    }
  }

  void requestKeyboard() {
    if (_isAttachedToKeyboard) {
      _keyboardHandle.show();
    } else {
      Focus.moveTo(config.focusKey);
    }
  }

  void _handleTextUpdated() {
    if (config.onChanged != null)
      config.onChanged(_keyboardClient.inputValue);
  }

  void _handleTextSubmitted() {
    Focus.clear(context);
    if (config.onSubmitted != null)
      config.onSubmitted(_keyboardClient.inputValue);
  }

  void _handleSelectionChanged(TextSelection selection) {
    // Note that this will show the keyboard for all selection changes on the
    // EditableLineWidget, not just changes triggered by user gestures.
    requestKeyboard();

    if (config.onChanged != null)
      config.onChanged(_keyboardClient.inputValue.copyWith(selection: selection));
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  bool get cursorCurrentlyVisible => _showCursor;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;

  void _cursorTick(Timer timer) {
    setState(() {
      _showCursor = !_showCursor;
    });
  }

  void _startCursorTimer() {
    _showCursor = true;
    _cursorTimer = new Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  void dispose() {
    if (_isAttachedToKeyboard)
      _keyboardHandle.release();
    if (_cursorTimer != null)
      _stopCursorTimer();
    super.dispose();
  }

  void _stopCursorTimer() {
    _cursorTimer.cancel();
    _cursorTimer = null;
    _showCursor = false;
  }

  Widget buildContent(BuildContext context) {
    assert(config.style != null);
    assert(config.focusKey != null);
    assert(config.cursorColor != null);

    bool focused = Focus.at(config.focusKey.currentContext);
    _attachOrDetachKeyboard(focused);

    if (_cursorTimer == null && focused && config.value.selection.isCollapsed)
      _startCursorTimer();
    else if (_cursorTimer != null && (!focused || !config.value.selection.isCollapsed))
      _stopCursorTimer();

    return new _EditableLineWidget(
      value: config.value,
      style: config.style,
      cursorColor: config.cursorColor,
      showCursor: _showCursor,
      selectionColor: config.selectionColor,
      hideText: config.hideText,
      onSelectionChanged: _handleSelectionChanged,
      paintOffset: scrollOffsetToPixelDelta(scrollOffset),
      onPaintOffsetUpdateNeeded: _handlePaintOffsetUpdateNeeded
    );
  }
}

class _EditableLineWidget extends LeafRenderObjectWidget {
  _EditableLineWidget({
    Key key,
    this.value,
    this.style,
    this.cursorColor,
    this.showCursor,
    this.selectionColor,
    this.hideText,
    this.onSelectionChanged,
    this.paintOffset,
    this.onPaintOffsetUpdateNeeded
  }) : super(key: key);

  final InputValue value;
  final TextStyle style;
  final Color cursorColor;
  final bool showCursor;
  final Color selectionColor;
  final bool hideText;
  final ValueChanged<TextSelection> onSelectionChanged;
  final Offset paintOffset;
  final ViewportDimensionsChangeCallback onPaintOffsetUpdateNeeded;

  RenderEditableLine createRenderObject() {
    return new RenderEditableLine(
      text: _styledTextSpan,
      cursorColor: cursorColor,
      showCursor: showCursor,
      selectionColor: selectionColor,
      selection: value.selection,
      onSelectionChanged: onSelectionChanged,
      paintOffset: paintOffset,
      onPaintOffsetUpdateNeeded: onPaintOffsetUpdateNeeded
    );
  }

  void updateRenderObject(RenderEditableLine renderObject,
                          _EditableLineWidget oldWidget) {
    renderObject
      ..text = _styledTextSpan
      ..cursorColor = cursorColor
      ..showCursor = showCursor
      ..selectionColor = selectionColor
      ..selection = value.selection
      ..onSelectionChanged = onSelectionChanged
      ..paintOffset = paintOffset
      ..onPaintOffsetUpdateNeeded = onPaintOffsetUpdateNeeded;
  }

  TextSpan get _styledTextSpan {
    if (!hideText && value.composing.isValid) {
      TextStyle composingStyle = style.merge(
        const TextStyle(decoration: TextDecoration.underline)
      );

      return new TextSpan(
        style: style,
        children: <TextSpan>[
          new TextSpan(text: value.composing.textBefore(value.text)),
          new TextSpan(
            style: composingStyle,
            text: value.composing.textInside(value.text)
          ),
          new TextSpan(text: value.composing.textAfter(value.text))
      ]);
    }

    String text = value.text;
    if (hideText)
      text = new String.fromCharCodes(new List<int>.filled(text.length, 0x2022));
    return new TextSpan(style: style, text: text);
  }
}
