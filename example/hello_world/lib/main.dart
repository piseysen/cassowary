// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/widgets/basic.dart';

class HelloWorldApp extends App {
  Widget build() {
    return new Center(child: new Text('Hello, world!'));
  }
}

void main() {
  runApp(new HelloWorldApp());
}
