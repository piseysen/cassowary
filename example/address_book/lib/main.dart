// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/editing/input.dart';
import 'package:sky/theme/colors.dart' as colors;
import 'package:sky/theme/typography.dart' as typography;
import 'package:sky/widgets/basic.dart';
import 'package:sky/widgets/default_text_style.dart';
import 'package:sky/widgets/floating_action_button.dart';
import 'package:sky/widgets/focus.dart';
import 'package:sky/widgets/icon.dart';
import 'package:sky/widgets/icon_button.dart';
import 'package:sky/widgets/material.dart';
import 'package:sky/widgets/scaffold.dart';
import 'package:sky/widgets/scrollable_viewport.dart';
import 'package:sky/widgets/task_description.dart';
import 'package:sky/widgets/theme.dart';
import 'package:sky/widgets/tool_bar.dart';
import 'package:sky/widgets/widget.dart';

class Field extends Component {
  Field({
    Key key,
    this.inputKey,
    this.icon,
    this.placeholder
  }): super(key: key);

  final GlobalKey inputKey;
  final String icon;
  final String placeholder;

  Widget build() {
    return new Flex([
        new Padding(
          padding: const EdgeDims.symmetric(horizontal: 16.0),
          child: new Icon(type: icon, size: 24)
        ),
        new Flexible(
          child: new Input(
            key: inputKey,
            placeholder: placeholder
          )
        )
      ],
      direction: FlexDirection.horizontal
    );
  }
}

class AddressBookApp extends App {

  Widget buildToolBar() {
    return new ToolBar(
        left: new IconButton(icon: "navigation/arrow_back"),
        right: [new IconButton(icon: "navigation/check")]
      );
  }

  Widget buildFloatingActionButton() {
    return new FloatingActionButton(
      child: new Icon(type: 'image/photo_camera', size: 24),
      backgroundColor: Theme.of(this).accentColor
    );
  }

  static final GlobalKey nameKey = new GlobalKey();
  static final GlobalKey phoneKey = new GlobalKey();
  static final GlobalKey emailKey = new GlobalKey();
  static final GlobalKey addressKey = new GlobalKey();
  static final GlobalKey ringtoneKey = new GlobalKey();
  static final GlobalKey noteKey = new GlobalKey();

  Widget buildBody() {
    return new Material(
      child: new ScrollableBlock([
        new AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: new Container(
            decoration: new BoxDecoration(backgroundColor: colors.Purple[300])
          )
        ),
        new Field(inputKey: nameKey, icon: "social/person", placeholder: "Name"),
        new Field(inputKey: phoneKey, icon: "communication/phone", placeholder: "Phone"),
        new Field(inputKey: emailKey, icon: "communication/email", placeholder: "Email"),
        new Field(inputKey: addressKey, icon: "maps/place", placeholder: "Address"),
        new Field(inputKey: ringtoneKey, icon: "av/volume_up", placeholder: "Ringtone"),
        new Field(inputKey: noteKey, icon: "content/add", placeholder: "Add note"),
      ])
    );
  }

  Widget buildMain() {
    return new Scaffold(
      toolbar: buildToolBar(),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton()
    );
  }

  Widget build() {
    ThemeData theme = new ThemeData(
      brightness: ThemeBrightness.light,
      primarySwatch: colors.Teal,
      accentColor: colors.PinkAccent[100]
    );
    return new Theme(
      data: theme,
      child: new DefaultTextStyle(
        style: typography.error, // if you see this, you've forgotten to correctly configure the text style!
        child: new TaskDescription(
          label: 'Address Book',
          child: new Focus(
            defaultFocus: nameKey,
            child: buildMain()
          )
        )
      )
    );
  }
}

void main() {
  runApp(new AddressBookApp());
}
