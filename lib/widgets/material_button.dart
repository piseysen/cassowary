// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/widgets/basic.dart';
import 'package:sky/widgets/button_base.dart';
import 'package:sky/widgets/gesture_detector.dart';
import 'package:sky/widgets/ink_well.dart';
import 'package:sky/widgets/material.dart';

// Rather than using this class directly, please use FlatButton or RaisedButton.
abstract class MaterialButton extends ButtonBase {

  MaterialButton({
    Key key,
    this.child,
    this.enabled: true,
    this.onPressed
  }) : super(key: key);

  Widget child;
  bool enabled;
  Function onPressed;

  void syncConstructorArguments(MaterialButton source) {
    child = source.child;
    enabled = source.enabled;
    onPressed = source.onPressed;
    super.syncConstructorArguments(source);
  }

  Color get color;
  int get level;

  Widget buildContent() {
    Widget contents = new Container(
      padding: new EdgeDims.symmetric(horizontal: 8.0),
      child: new Center(child: child) // TODO(ianh): figure out a way to compell the child to have gray text when disabled...
    );
    return new GestureDetector(
      onTap: enabled ? onPressed : null,
      child: new Container(
        height: 36.0,
        constraints: new BoxConstraints(minWidth: 88.0),
        margin: new EdgeDims.all(8.0),
        child: new Material(
          type: MaterialType.button,
          child: enabled ? new InkWell(child: contents) : contents,
          level: level,
          color: color
        )
      )
    );
  }

}
