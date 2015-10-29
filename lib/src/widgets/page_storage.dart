// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'framework.dart';

class _StorageEntryIdentifier {
  Type clientType;
  List<Key> keys;
  void addKey(Key key) {
    assert(key != null);
    assert(key is! GlobalKey);
    keys ??= <Key>[];
    keys.add(key);
  }
  GlobalKey scopeKey;
  bool operator ==(dynamic other) {
    if (other is! _StorageEntryIdentifier)
      return false;
    final _StorageEntryIdentifier typedOther = other;
    if (clientType != typedOther.clientType ||
        scopeKey != typedOther.scopeKey ||
        keys?.length != typedOther.keys?.length)
      return false;
    if (keys != null) {
      for (int index = 0; index < keys.length; index += 1) {
        if (keys[index] != typedOther.keys[index])
          return false;
      }
    }
    return true;
  }
  int get hashCode {
    int value = 373;
    value = 37 * value + clientType.hashCode;
    value = 37 * value + scopeKey.hashCode;
    if (keys != null) {
      for (Key key in keys)
        value = 37 * value + key.hashCode;
    }
    return value;
  }
}

class PageStorageBucket {
  _StorageEntryIdentifier _computeStorageIdentifier(BuildContext context) {
    _StorageEntryIdentifier result = new _StorageEntryIdentifier();
    result.clientType = context.widget.runtimeType;
    Key lastKey = context.widget.key;
    if (lastKey is! GlobalKey) {
      context.visitAncestorElements((Element element) {
        if (element.widget.key is GlobalKey) {
          lastKey = element.widget.key;
          return false;
        } else if (element.widget.key != null) {
          result.addKey(element.widget.key);
        }
        return true;
      });
      return result;
    }
    assert(lastKey is GlobalKey);
    result.scopeKey = lastKey;
    return result;
  }

  Map<_StorageEntryIdentifier, dynamic> _storage;
  void writeState(BuildContext context, dynamic data) {
    _storage ??= <_StorageEntryIdentifier, dynamic>{};
    _storage[_computeStorageIdentifier(context)] = data;
  }
  dynamic readState(BuildContext context) {
    return _storage != null ? _storage[_computeStorageIdentifier(context)] : null;
  }
}

class PageStorage extends StatelessComponent {
  PageStorage({
    Key key,
    this.child,
    this.bucket
  }) : super(key: key);

  final Widget child;
  final PageStorageBucket bucket;

  /// Might return null if there is no PageStorage in this context.
  static PageStorageBucket of(BuildContext context) {
    PageStorageBucket result;
    context.visitAncestorElements((Element element) {
      Widget widget = element.widget;
      if (widget is PageStorage) {
        result = widget.bucket;
        return false;
      }
      return true;
    });
    return result;
  }

  Widget build(BuildContext context) => child;
}
