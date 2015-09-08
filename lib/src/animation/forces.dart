// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:newton/newton.dart';

// Base class for creating Simulations for the animation Timeline.
abstract class Force {
  const Force();

  Simulation release(double position, double velocity);
}

class SpringForce extends Force {
  const SpringForce(this.spring, { this.left: 0.0, this.right: 1.0 });

  final SpringDescription spring;

  // Where to put the spring's resting point when releasing left or right,
  // respectively.
  final double left;
  final double right;

  // We overshoot the target by this distance, but stop the simulation when
  // the spring gets within this distance (regardless of how fast it's moving).
  // This causes the spring to settle a bit faster than it otherwise would.
  static const Tolerance tolerance = const Tolerance(
    velocity: double.INFINITY,
    distance: 0.01
  );

  Simulation release(double position, double velocity) {
    double target = velocity < 0.0 ? this.left - tolerance.distance
                                   : this.right + tolerance.distance;
    return new SpringSimulation(spring, position, target, velocity)
      ..tolerance = tolerance;
  }
}

final SpringDescription _kDefaultSpringDesc = new SpringDescription.withDampingRatio(
  mass: 1.0,
  springConstant: 500.0,
  ratio: 1.0
);

final SpringForce kDefaultSpringForce = new SpringForce(_kDefaultSpringDesc);
