// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mojo_services/keyboard/keyboard.mojom.dart';
import 'package:sky/src/services/shell.dart';

export 'package:mojo_services/keyboard/keyboard.mojom.dart';

class _KeyboardConnection {

  _KeyboardConnection() {
    proxy = new KeyboardServiceProxy.unbound();
    shell.requestService("mojo:keyboard", proxy);
  }

  KeyboardServiceProxy proxy;
  KeyboardService get keyboardService => proxy.ptr;

  static final _KeyboardConnection instance = new _KeyboardConnection();
}

class Keyboard {

  Keyboard(this.service);

  // The service is exposed in case you need direct access.
  // However, as a general rule, you should be able to do
  // most of what you need using only this class.
  final KeyboardService service;

  KeyboardHandle _currentHandle;

  KeyboardHandle show(KeyboardClientStub stub, int keyboardType) {
    assert(stub != null);
    if (_currentHandle != null) {
      if (_currentHandle.stub == stub)
        return _currentHandle;
      _currentHandle.release();
    }
    _currentHandle = new KeyboardHandle._show(this, stub, keyboardType);
    return _currentHandle;
  }

}

class KeyboardHandle {

  KeyboardHandle._show(Keyboard keyboard, this.stub, int keyboardType) : _keyboard = keyboard {
    _keyboard.service.show(stub, keyboardType);
    _attached = true;
  }

  KeyboardHandle._unattached(Keyboard keyboard) : _keyboard = keyboard, stub = null, _attached = false;
  static final unattached = new KeyboardHandle._unattached(keyboard);

  final Keyboard _keyboard;
  final KeyboardClientStub stub;

  bool _attached;
  bool get attached => _attached;

  void showByRequest() {
    assert(_attached);
    assert(_keyboard._currentHandle == this);
    _keyboard.service.showByRequest();
  }

  void release() {
    if (_attached) {
      assert(_keyboard._currentHandle == this);
      _keyboard.service.hide();
      _attached = false;
      _keyboard._currentHandle = null;
    }
    assert(_keyboard._currentHandle != this);
  }

}

final Keyboard keyboard = new Keyboard(_KeyboardConnection.instance.keyboardService);
