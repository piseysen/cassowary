// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/animation/animation_performance.dart';
import 'package:sky/widgets/framework.dart';

abstract class AnimatedComponent extends StatefulComponent {

  AnimatedComponent({ Key key }) : super(key: key);

  void syncConstructorArguments(AnimatedComponent source) { }

  final List<AnimationPerformance> _watchedPerformances = new List<AnimationPerformance>();

  void _performanceChanged() {
    setState(() {
      // We don't actually have any state to change, per se,
      // we just know that we have in fact changed state.
    });
  }

  bool isWatching(performance) => _watchedPerformances.contains(performance);

  void watch(AnimationPerformance performance) {
    assert(!isWatching(performance));
    _watchedPerformances.add(performance);
    if (mounted)
      performance.addListener(_performanceChanged);
  }

  void unwatch(AnimationPerformance performance) {
    assert(isWatching(performance));
    _watchedPerformances.remove(performance);
    if (mounted)
      performance.removeListener(_performanceChanged);
  }

  void didMount() {
    for (AnimationPerformance performance in _watchedPerformances)
      performance.addListener(_performanceChanged);
    super.didMount();
  }

  void didUnmount() {
    for (AnimationPerformance performance in _watchedPerformances)
      performance.removeListener(_performanceChanged);
    super.didUnmount();
  }

}
