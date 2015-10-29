// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';

class OverlayEntry {
  OverlayEntry({
    this.child,
    bool opaque: false
  }) : _opaque = opaque;

  final Widget child;

  bool get opaque => _opaque;
  bool _opaque;
  void set opaque(bool value) {
    _opaque = value;
    _state?.setState(() {});
  }

  OverlayState _state;

  /// Remove the entry from the overlay.
  void remove() {
    _state?._remove(this);
    _state = null;
  }
}

class Overlay extends StatefulComponent {
  Overlay({
    Key key,
    this.initialEntries
  }) : super(key: key);

  final List<OverlayEntry> initialEntries;

  OverlayState createState() => new OverlayState();
}

class OverlayState extends State<Overlay> {
  final List<OverlayEntry> _entries = new List<OverlayEntry>();

  void initState() {
    super.initState();
    for (OverlayEntry entry in config.initialEntries)
      insert(entry);
  }

  void insert(OverlayEntry entry, { OverlayEntry above }) {
    assert(entry._state == null);
    if (above != null) {
      print('above._state ${above._state} --- ${above._state == this}');
      print('_entries.contains ${_entries.contains(above)}');
    }
    assert(above == null || (above._state == this && _entries.contains(above)));
    entry._state = this;
    setState(() {
      int index = above == null ? _entries.length : _entries.indexOf(above) + 1;
      _entries.insert(index, entry);
    });
  }

  void _remove(OverlayEntry entry) {
    setState(() {
      _entries.remove(entry);
    });
  }

  Widget build(BuildContext context) {
    List<Widget> backwardsChildren = <Widget>[];

    for (int i = _entries.length - 1; i >= 0; --i) {
      OverlayEntry entry = _entries[i];
      backwardsChildren.add(new KeyedSubtree(
        key: new ObjectKey(entry),
        child: entry.child
      ));
      if (entry.opaque)
        break;
    }

    return new Stack(backwardsChildren.reversed.toList(growable: false));
  }
}
