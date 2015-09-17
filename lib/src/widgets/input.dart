// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/services.dart';
import 'package:sky/painting.dart';
import 'package:sky/src/widgets/basic.dart';
import 'package:sky/src/widgets/editable_text.dart';
import 'package:sky/src/widgets/focus.dart';
import 'package:sky/src/widgets/framework.dart';
import 'package:sky/src/widgets/theme.dart';

export 'package:sky/services.dart' show KeyboardType_TEXT, KeyboardType_NUMBER, KeyboardType_PHONE, KeyboardType_DATETIME;

typedef void StringValueChanged(String value);

// TODO(eseidel): This isn't right, it's 16px on the bottom:
// http://www.google.com/design/spec/components/text-fields.html#text-fields-single-line-text-field
const EdgeDims _kTextfieldPadding = const EdgeDims.symmetric(vertical: 8.0);

class Input extends StatefulComponent {

  Input({
    GlobalKey key,
    String initialValue: '',
    this.placeholder,
    this.onChanged,
    this.keyboardType : KeyboardType_TEXT
  }): _value = initialValue, super(key: key);

  int keyboardType;
  String placeholder;
  StringValueChanged onChanged;

  String _value;
  EditableString _editableValue;
  KeyboardHandle _keyboardHandle = KeyboardHandle.unattached;

  void initState() {
    _editableValue = new EditableString(
      text: _value,
      onUpdated: _handleTextUpdated
    );
    super.initState();
  }

  void syncConstructorArguments(Input source) {
    placeholder = source.placeholder;
    onChanged = source.onChanged;
    keyboardType = source.keyboardType;
  }

  void _handleTextUpdated() {
    if (_value != _editableValue.text) {
      setState(() {
        _value = _editableValue.text;
      });
      if (onChanged != null)
        onChanged(_value);
    }
  }

  Widget build() {
    ThemeData themeData = Theme.of(this);
    bool focused = Focus.at(this);

    if (focused && !_keyboardHandle.attached) {
      _keyboardHandle = keyboard.show(_editableValue.stub, keyboardType);
    } else if (!focused && _keyboardHandle.attached) {
      _keyboardHandle.release();
    }

    TextStyle textStyle = themeData.text.subhead;
    List<Widget> textChildren = <Widget>[];

    if (placeholder != null && _value.isEmpty) {
      Widget child = new Opacity(
        key: const ValueKey<String>('placeholder'),
        child: new Text(placeholder, style: textStyle),
        opacity: themeData.hintOpacity
      );
      textChildren.add(child);
    }

    Color focusHighlightColor = themeData.accentColor;
    Color cursorColor = themeData.accentColor;
    if (themeData.primarySwatch != null) {
      cursorColor = themeData.primarySwatch[200];
      focusHighlightColor = focused ? themeData.primarySwatch[400] : themeData.hintColor;
    }

    textChildren.add(new EditableText(
      value: _editableValue,
      focused: focused,
      style: textStyle,
      cursorColor: cursorColor
    ));

    Border focusHighlight = new Border(bottom: new BorderSide(
      color: focusHighlightColor,
      width: focused ? 2.0 : 1.0
    ));

    Container input = new Container(
      child: new Stack(textChildren),
      padding: _kTextfieldPadding,
      decoration: new BoxDecoration(border: focusHighlight)
    );

    return new Listener(
      child: input,
      onPointerDown: focus
    );
  }

  EventDisposition focus(_) {
    if (Focus.at(this)) {
      assert(_keyboardHandle.attached);
      _keyboardHandle.showByRequest();
    } else {
      Focus.moveTo(this);
      // we'll get told to rebuild and we'll take care of the keyboard then
    }
    return EventDisposition.processed;
  }

  void didUnmount() {
    if (_keyboardHandle.attached)
      _keyboardHandle.release();
    super.didUnmount();
  }
}
