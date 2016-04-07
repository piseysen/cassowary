// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'material.dart';

const EdgeInsets _kCardMargins = const EdgeInsets.all(4.0);

/// A material design card
///
/// See also:
///
///  * [Dialog]
///  * [showDialog]
///  * <https://www.google.com/design/spec/components/cards.html>
class Card extends StatelessWidget {
  const Card({ Key key, this.child, this.color }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// The color of material used for this card.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return new Container(
      margin: _kCardMargins,
      child: new Material(
        color: color,
        type: MaterialType.card,
        elevation: 2,
        child: child
      )
    );
  }
}
