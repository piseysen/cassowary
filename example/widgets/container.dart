// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/rendering/box.dart';
import 'package:sky/rendering/flex.dart';
import 'package:sky/widgets/raised_button.dart';
import 'package:sky/widgets/basic.dart';

class ContainerApp extends App {
  Widget build() {
    return new Flex([
        new Container(
          padding: new EdgeDims.all(10.0),
          margin: new EdgeDims.all(10.0),
          decoration: new BoxDecoration(backgroundColor: const Color(0xFFCCCCCC)),
          child: new NetworkImage(
            src: "https://www.dartlang.org/logos/dart-logo.png",
            width: 300.0,
            height: 300.0
          )
        ),
        new Container(
          decoration: new BoxDecoration(backgroundColor: const Color(0xFFFFFF00)),
          padding: new EdgeDims.symmetric(horizontal: 50.0, vertical: 75.0),
          child: new Flex([
            new RaisedButton(
              child: new Text('PRESS ME'),
              onPressed: () => print("Hello World")
            ),
            new RaisedButton(
              child: new Text('DISABLED'),
              onPressed: () => print("Hello World"),
              enabled: false
            )
          ])
        ),
        new Flexible(
          child: new Container(
            decoration: new BoxDecoration(backgroundColor: const Color(0xFF00FFFF))
          )
        ),
      ],
      direction: FlexDirection.vertical,
      justifyContent: FlexJustifyContent.spaceBetween
    );
  }
}

void main() {
  runApp(new ContainerApp());
}
