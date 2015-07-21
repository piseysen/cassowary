// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/widgets/basic.dart';
import 'package:sky/widgets/material.dart';

const EdgeDims kCardMargins = const EdgeDims.all(4.0);

/// A material design card
///
/// <https://www.google.com/design/spec/components/cards.html>
class Card extends Component {
  Card({ String key, this.child, this.color }) : super(key: key);

  final Widget child;
  final Color color;

  Widget build() {
    return new Container(
      margin: kCardMargins,
      child: new Material(
        color: color,
        type: MaterialType.card,
        level: 2,
        child: new ClipRRect(
          xRadius: edges[MaterialType.card],
          yRadius: edges[MaterialType.card],
          child: child
        )
      )
    );
  }
}
