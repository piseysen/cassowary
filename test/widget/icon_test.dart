// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  test('Can set opacity for an Icon', () {
    testWidgets((WidgetTester tester) {
      tester.pumpWidget(
        new IconTheme(
          data: new IconThemeData(
            color: Colors.green[500],
            opacity: 0.5
          ),
          child: new Icon(icon: Icons.add)
        )
      );
      Text text = tester.widget(find.byType(Text));
      expect(text.style.color, equals(Colors.green[500].withOpacity(0.5)));
    });
  });
}
