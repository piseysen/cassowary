// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';

/// Whether in portrait or landscape.
enum Orientation {
  /// Taller than wide.
  portrait,

  /// Wider than tall.
  landscape
}

/// The result of a media query.
class MediaQueryData {
  const MediaQueryData({ this.size, this.devicePixelRatio, this.padding });

  /// The size of the media (e.g, the size of the screen).
  final Size size;

  /// The number of device pixels for each logical pixel. This number might not
  /// be a power of two. Indeed, it might not even be an integer. For example,
  /// the Nexus 6 has a device pixel ratio of 3.5.
  final double devicePixelRatio;

  /// The padding around the edges of the media (e.g., the screen).
  final EdgeDims padding;

  /// The orientation of the media (e.g., whether the device is in landscape or portrait mode).
  Orientation get orientation {
    return size.width > size.height ? Orientation.landscape : Orientation.portrait;
  }

  bool operator==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    MediaQueryData typedOther = other;
    return typedOther.size == size
        && typedOther.padding == padding
        && typedOther.devicePixelRatio == devicePixelRatio;
  }

  int get hashCode => hashValues(
    size.hashCode,
    padding.hashCode,
    devicePixelRatio.hashCode
  );

  String toString() => '$runtimeType($size, $orientation)';
}

/// Establishes a subtree in which media queries resolve to the given data.
class MediaQuery extends InheritedWidget {
  MediaQuery({
    Key key,
    this.data,
    Widget child
  }) : super(key: key, child: child) {
    assert(child != null);
    assert(data != null);
  }

  /// The result of media queries in this subtree.
  final MediaQueryData data;

  /// The data from the closest instance of this class that encloses the given context.
  ///
  /// You can use this function to query the size an orientation of the screen.
  /// When that information changes, your widget will be scheduled to be rebuilt,
  /// keeping your widget up-to-date.
  static MediaQueryData of(BuildContext context) {
    MediaQuery query = context.inheritFromWidgetOfExactType(MediaQuery);
    return query == null ? null : query.data;
  }

  bool updateShouldNotify(MediaQuery old) => data != old.data;

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$data');
  }
}
