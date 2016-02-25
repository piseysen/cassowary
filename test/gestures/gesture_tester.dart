// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

class TestGestureFlutterBinding extends BindingBase with Gesturer { }

void ensureGesturer() {
  if (Gesturer.instance == null)
    new TestGestureFlutterBinding();
  assert(Gesturer.instance != null);
}
