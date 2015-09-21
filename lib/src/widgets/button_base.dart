// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/src/widgets/framework.dart';

abstract class ButtonBase extends StatefulComponent {

  ButtonBase({ Key key, this.highlight: false }) : super(key: key);

  bool highlight;

  void syncConstructorArguments(ButtonBase source) {
    highlight = source.highlight;
  }

  void _handlePointerDown(_) {
    setState(() {
      highlight = true;
    });
  }

  void _handlePointerUp(_) {
    setState(() {
      highlight = false;
    });
  }

  void _handlePointerCancel(_) {
    setState(() {
      highlight = false;
    });
  }

  Widget build() {
    return new Listener(
      child: buildContent(),
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel
    );
  }

  Widget buildContent();

}
