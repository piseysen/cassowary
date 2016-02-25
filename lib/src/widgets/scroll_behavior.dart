// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:newton/newton.dart';

const double _kSecondsPerMillisecond = 1000.0;
const double _kScrollDrag = 0.025;

/// An interface for controlling the behavior of scrollable widgets.
///
/// The type argument T is the type that describes the scroll offset.
/// The type argument U is the type that describes the scroll velocity.
abstract class ScrollBehavior<T, U> {
  /// Returns a simulation that propels the scrollOffset.
  ///
  /// This function is called when a drag gesture ends.
  ///
  /// Returns null if the behavior is to do nothing.
  Simulation createFlingScrollSimulation(T position, U velocity) => null;

  /// Returns an animation that ends at the snap offset.
  ///
  /// This function is called when a drag gesture ends and a
  /// [SnapOffsetCallback] is specified for the scrollable.
  ///
  /// Returns null if the behavior is to do nothing.
  Simulation createSnapScrollSimulation(T startOffset, T endOffset, U startVelocity, U endVelocity) => null;

  /// Returns the scroll offset to use when the user attempts to scroll
  /// from the given offset by the given delta.
  T applyCurve(T scrollOffset, T scrollDelta) => scrollOffset;

  /// Whether this scroll behavior currently permits scrolling
  bool get isScrollable => true;

  String toString() {
    List<String> description = <String>[];
    debugFillDescription(description);
    return '$runtimeType(${description.join("; ")})';
  }
  void debugFillDescription(List<String> description) {
    description.add(isScrollable ? 'scrollable' : 'not scrollable');
  }
}

/// A scroll behavior for a scrollable widget with linear extent (i.e.
/// that only scrolls along one axis).
abstract class ExtentScrollBehavior extends ScrollBehavior<double, double> {
  ExtentScrollBehavior({ double contentExtent: 0.0, double containerExtent: 0.0 })
    : _contentExtent = contentExtent, _containerExtent = containerExtent;

  /// The linear extent of the content inside the scrollable widget.
  double get contentExtent => _contentExtent;
  double _contentExtent;

  /// The linear extent of the exterior of the scrollable widget.
  double get containerExtent => _containerExtent;
  double _containerExtent;

  /// Updates either content or container extent (or both)
  ///
  /// Returns the new scroll offset of the widget after the change in extent.
  ///
  /// The [scrollOffset] parameter is the scroll offset of the widget before the
  /// change in extent.
  double updateExtents({
    double contentExtent,
    double containerExtent,
    double scrollOffset: 0.0
  }) {
    if (contentExtent != null)
      _contentExtent = contentExtent;
    if (containerExtent != null)
      _containerExtent = containerExtent;
    return scrollOffset.clamp(minScrollOffset, maxScrollOffset);
  }

  /// The minimum value the scroll offset can obtain.
  double get minScrollOffset;

  /// The maximum value the scroll offset can obtain.
  double get maxScrollOffset;

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('content: ${contentExtent.toStringAsFixed(1)}');
    description.add('container: ${contentExtent.toStringAsFixed(1)}');
    description.add('range: ${minScrollOffset?.toStringAsFixed(1)} .. ${maxScrollOffset?.toStringAsFixed(1)}');
  }
}

/// A scroll behavior that prevents the user from exceeding scroll bounds.
class BoundedBehavior extends ExtentScrollBehavior {
  BoundedBehavior({
    double contentExtent: 0.0,
    double containerExtent: 0.0,
    double minScrollOffset: 0.0
  }) : _minScrollOffset = minScrollOffset,
       super(contentExtent: contentExtent, containerExtent: containerExtent);

  double _minScrollOffset;

  double updateExtents({
    double contentExtent,
    double containerExtent,
    double minScrollOffset,
    double scrollOffset: 0.0
  }) {
    if (minScrollOffset != null)
      _minScrollOffset = minScrollOffset;
    return super.updateExtents(
      contentExtent: contentExtent,
      containerExtent: containerExtent,
      scrollOffset: scrollOffset
    );
  }

  double get minScrollOffset => _minScrollOffset;
  double get maxScrollOffset => math.max(minScrollOffset, minScrollOffset + _contentExtent - _containerExtent);

  double applyCurve(double scrollOffset, double scrollDelta) {
    return (scrollOffset + scrollDelta).clamp(minScrollOffset, maxScrollOffset);
  }
}

Simulation _createFlingScrollSimulation(double position, double velocity, double minScrollOffset, double maxScrollOffset) {
  final double startVelocity = velocity * _kSecondsPerMillisecond;
  final SpringDescription spring = new SpringDescription.withDampingRatio(mass: 1.0, springConstant: 170.0, ratio: 1.1);
  return new ScrollSimulation(position, startVelocity, minScrollOffset, maxScrollOffset, spring, _kScrollDrag);
}

Simulation _createSnapScrollSimulation(double startOffset, double endOffset, double startVelocity, double endVelocity) {
  final double velocity = startVelocity * _kSecondsPerMillisecond;
  return new FrictionSimulation.through(startOffset, endOffset, velocity, endVelocity);
}

/// A scroll behavior that does not prevent the user from exeeding scroll bounds.
class UnboundedBehavior extends ExtentScrollBehavior {
  UnboundedBehavior({ double contentExtent: 0.0, double containerExtent: 0.0 })
    : super(contentExtent: contentExtent, containerExtent: containerExtent);

  Simulation createFlingScrollSimulation(double position, double velocity) {
    double velocityPerSecond = velocity * 1000.0;
    return new BoundedFrictionSimulation(
      _kScrollDrag, position, velocityPerSecond, double.NEGATIVE_INFINITY, double.INFINITY
    );
  }

  Simulation createSnapScrollSimulation(double startOffset, double endOffset, double startVelocity, double endVelocity) {
    return _createSnapScrollSimulation(startOffset, endOffset, startVelocity, endVelocity);
  }

  double get minScrollOffset => double.NEGATIVE_INFINITY;
  double get maxScrollOffset => double.INFINITY;

  double applyCurve(double scrollOffset, double scrollDelta) {
    return scrollOffset + scrollDelta;
  }
}

/// A scroll behavior that lets the user scroll beyond the scroll bounds with some resistance.
class OverscrollBehavior extends BoundedBehavior {
  OverscrollBehavior({ double contentExtent: 0.0, double containerExtent: 0.0, double minScrollOffset: 0.0 })
    : super(contentExtent: contentExtent, containerExtent: containerExtent, minScrollOffset: minScrollOffset);

  Simulation createFlingScrollSimulation(double position, double velocity) {
    return _createFlingScrollSimulation(position, velocity, minScrollOffset, maxScrollOffset);
  }

  Simulation createSnapScrollSimulation(double startOffset, double endOffset, double startVelocity, double endVelocity) {
    return _createSnapScrollSimulation(startOffset, endOffset, startVelocity, endVelocity);
  }

  double applyCurve(double scrollOffset, double scrollDelta) {
    double newScrollOffset = scrollOffset + scrollDelta;
    // If we're overscrolling, we want move the scroll offset 2x
    // slower than we would otherwise. Therefore, we "rewind" the
    // newScrollOffset by half the amount that we moved it above.
    // Notice that we clamp the "old" value to 0.0 so that we only
    // reduce the portion of scrollDelta that's applied beyond 0.0. We
    // do similar things for overscroll in the other direction.
    if (newScrollOffset < minScrollOffset) {
      newScrollOffset -= (newScrollOffset - math.min(minScrollOffset, scrollOffset)) / 2.0;
    } else if (newScrollOffset > maxScrollOffset) {
      newScrollOffset -= (newScrollOffset - math.max(maxScrollOffset, scrollOffset)) / 2.0;
    }
    return newScrollOffset;
  }
}

/// A scroll behavior that lets the user scroll beyond the scroll bounds only when the bounds are disjoint.
class OverscrollWhenScrollableBehavior extends OverscrollBehavior {
  OverscrollWhenScrollableBehavior({ double contentExtent: 0.0, double containerExtent: 0.0, double minScrollOffset: 0.0 })
    : super(contentExtent: contentExtent, containerExtent: containerExtent, minScrollOffset: minScrollOffset);

  bool get isScrollable => contentExtent > containerExtent;

  Simulation createFlingScrollSimulation(double position, double velocity) {
    if (isScrollable || position < minScrollOffset || position > maxScrollOffset)
      return super.createFlingScrollSimulation(position, velocity);
    return null;
  }

  double applyCurve(double scrollOffset, double scrollDelta) {
    if (isScrollable)
      return super.applyCurve(scrollOffset, scrollDelta);
    return minScrollOffset;
  }
}
