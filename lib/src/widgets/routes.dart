// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/animation.dart';

import 'basic.dart';
import 'focus.dart';
import 'framework.dart';
import 'modal_barrier.dart';
import 'navigator.dart';
import 'overlay.dart';
import 'page_storage.dart';
import 'pages.dart';

const _kTransparent = const Color(0x00000000);

/// A route that displays widgets in the [Navigator]'s [Overlay].
abstract class OverlayRoute<T> extends Route<T> {
  /// Subclasses should override this getter to return the builders for the overlay.
  List<WidgetBuilder> get builders;

  /// The entries this route has placed in the overlay.
  List<OverlayEntry> get overlayEntries => _overlayEntries;
  final List<OverlayEntry> _overlayEntries = <OverlayEntry>[];

  void install(OverlayEntry insertionPoint) {
    assert(_overlayEntries.isEmpty);
    for (WidgetBuilder builder in builders)
      _overlayEntries.add(new OverlayEntry(builder: builder));
    navigator.overlay?.insertAll(_overlayEntries, above: insertionPoint);
  }

  /// A request was made to pop this route. If the route can handle it
  /// internally (e.g. because it has its own stack of internal state) then
  /// return false, otherwise return true. Returning false will prevent the
  /// default behavior of NavigatorState.pop().
  ///
  /// If this is called, the Navigator will not call dispose(). It is the
  /// responsibility of the Route to later call dispose().
  ///
  /// Subclasses shouldn't call this if they want to delay the finished() call.
  bool didPop(T result) {
    finished();
    return true;
  }

  /// Clears out the overlay entries.
  ///
  /// This method is intended to be used by subclasses who don't call
  /// super.didPop() because they want to have control over the timing of the
  /// overlay removal.
  ///
  /// Do not call this method outside of this context.
  void finished() {
    for (OverlayEntry entry in _overlayEntries)
      entry.remove();
    _overlayEntries.clear();
  }

  void dispose() {
    finished();
  }
}

abstract class TransitionRoute<T> extends OverlayRoute<T> {
  TransitionRoute({
    Completer<T> popCompleter,
    Completer<T> transitionCompleter
  }) : _popCompleter = popCompleter,
       _transitionCompleter = transitionCompleter;

  TransitionRoute.explicit(
    Completer<T> popCompleter,
    Completer<T> transitionCompleter
  ) : this(popCompleter: popCompleter, transitionCompleter: transitionCompleter);

  /// This future completes once the animation has been dismissed. For
  /// ModalRoutes, this will be after the completer that's passed in, since that
  /// one completes before the animation even starts, as soon as the route is
  /// popped.
  Future<T> get popped => _popCompleter?.future;
  final Completer<T> _popCompleter;

  /// This future completes only once the transition itself has finished, after
  /// the overlay entries have been removed from the navigator's overlay.
  Future<T> get completed => _transitionCompleter?.future;
  final Completer<T> _transitionCompleter;

  Duration get transitionDuration;
  bool get opaque;

  PerformanceView get performance => _performance;
  Performance _performanceController;
  PerformanceView _performance;

  /// Called to create the Performance object that will drive the transitions to
  /// this route from the previous one, and back to the previous route from this
  /// one.
  Performance createPerformanceController() {
    Duration duration = transitionDuration;
    assert(duration != null && duration >= Duration.ZERO);
    return new Performance(duration: duration, debugLabel: debugLabel);
  }

  /// Called to create the PerformanceView that exposes the current progress of
  /// the transition controlled by the Performance object created by
  /// [createPerformanceController()].
  PerformanceView createPerformance() {
    assert(_performanceController != null);
    return _performanceController.view;
  }

  T _result;

  void handleStatusChanged(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.completed:
        if (overlayEntries.isNotEmpty)
          overlayEntries.first.opaque = opaque;
        break;
      case PerformanceStatus.forward:
      case PerformanceStatus.reverse:
        if (overlayEntries.isNotEmpty)
          overlayEntries.first.opaque = false;
        break;
      case PerformanceStatus.dismissed:
        assert(!overlayEntries.first.opaque);
        finished(); // clear the overlays
        assert(overlayEntries.isEmpty);
        break;
    }
  }

  PerformanceView get forwardPerformance => _forwardPerformance;
  final ProxyPerformance _forwardPerformance = new ProxyPerformance(alwaysDismissedPerformance);

  void install(OverlayEntry insertionPoint) {
    _performanceController = createPerformanceController();
    assert(_performanceController != null);
    _performance = createPerformance();
    assert(_performance != null);
    super.install(insertionPoint);
  }

  void didPush() {
    _performance.addStatusListener(handleStatusChanged);
    _performanceController.forward();
    super.didPush();
  }

  void didReplace(Route oldRoute) {
    if (oldRoute is TransitionRoute)
      _performanceController.progress = oldRoute._performanceController.progress;
    _performance.addStatusListener(handleStatusChanged);
    super.didReplace(oldRoute);
  }

  bool didPop(T result) {
    _result = result;
    _performanceController.reverse();
    _popCompleter?.complete(_result);
    return true;
  }

  void didPopNext(Route nextRoute) {
    _updateForwardPerformance(nextRoute);
    super.didPopNext(nextRoute);
  }

  void didChangeNext(Route nextRoute) {
    _updateForwardPerformance(nextRoute);
    super.didChangeNext(nextRoute);
  }

  void _updateForwardPerformance(Route nextRoute) {
    if (nextRoute is TransitionRoute && canTransitionTo(nextRoute) && nextRoute.canTransitionFrom(this)) {
      PerformanceView current = _forwardPerformance.masterPerformance;
      if (current != null) {
        if (current is TrainHoppingPerformance) {
          TrainHoppingPerformance newPerformance;
          newPerformance = new TrainHoppingPerformance(
            current.currentTrain,
            nextRoute.performance,
            onSwitchedTrain: () {
              assert(_forwardPerformance.masterPerformance == newPerformance);
              assert(newPerformance.currentTrain == nextRoute.performance);
              _forwardPerformance.masterPerformance = newPerformance.currentTrain;
              newPerformance.dispose();
            }
          );
          _forwardPerformance.masterPerformance = newPerformance;
          current.dispose();
        } else {
          _forwardPerformance.masterPerformance = new TrainHoppingPerformance(current, nextRoute.performance);
        }
      } else {
        _forwardPerformance.masterPerformance = nextRoute.performance;
      }
    } else {
      _forwardPerformance.masterPerformance = alwaysDismissedPerformance;
    }
  }

  bool canTransitionTo(TransitionRoute nextRoute) => true;
  bool canTransitionFrom(TransitionRoute nextRoute) => true;

  void finished() {
    super.finished();
    _transitionCompleter?.complete(_result);
  }

  void dispose() {
    _performanceController.stop();
    super.dispose();
  }

  String get debugLabel => '$runtimeType';
  String toString() => '$runtimeType(performance: $_performanceController)';
}

class LocalHistoryEntry {
  LocalHistoryEntry({ this.onRemove });
  final VoidCallback onRemove;
  LocalHistoryRoute _owner;
  void remove() {
    _owner.removeLocalHistoryEntry(this);
    assert(_owner == null);
  }
  void _notifyRemoved() {
    if (onRemove != null)
      onRemove();
  }
}

abstract class LocalHistoryRoute<T> extends Route<T> {
  List<LocalHistoryEntry> _localHistory;
  void addLocalHistoryEntry(LocalHistoryEntry entry) {
    assert(entry._owner == null);
    entry._owner = this;
    _localHistory ??= <LocalHistoryEntry>[];
    _localHistory.add(entry);
  }
  void removeLocalHistoryEntry(LocalHistoryEntry entry) {
    assert(entry != null);
    assert(entry._owner == this);
    assert(_localHistory.contains(entry));
    _localHistory.remove(entry);
    entry._owner = null;
    entry._notifyRemoved();
  }
  bool didPop(T result) {
    if (_localHistory != null && _localHistory.length > 0) {
      LocalHistoryEntry entry = _localHistory.removeLast();
      assert(entry._owner == this);
      entry._owner = null;
      entry._notifyRemoved();
      return false;
    }
    return super.didPop(result);
  }
  bool get willHandlePopInternally {
    return _localHistory != null && _localHistory.length > 0;
  }
}

class _ModalScopeStatus extends InheritedWidget {
  _ModalScopeStatus({
    Key key,
    this.isCurrent,
    this.route,
    Widget child
  }) : super(key: key, child: child) {
    assert(isCurrent != null);
    assert(route != null);
    assert(child != null);
  }

  final bool isCurrent;
  final Route route;

  bool updateShouldNotify(_ModalScopeStatus old) {
    return isCurrent != old.isCurrent ||
           route != old.route;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('${isCurrent ? "active" : "inactive"}');
  }
}

class _ModalScope extends StatefulComponent {
  _ModalScope({
    Key key,
    this.route
  }) : super(key: key);

  final ModalRoute route;

  _ModalScopeState createState() => new _ModalScopeState();
}

class _ModalScopeState extends State<_ModalScope> {
  void initState() {
    super.initState();
    config.route.performance?.addStatusListener(_performanceStatusChanged);
    config.route.forwardPerformance?.addStatusListener(_performanceStatusChanged);
  }

  void didUpdateConfig(_ModalScope oldConfig) {
    assert(config.route == oldConfig.route);
  }

  void dispose() {
    config.route.performance?.removeStatusListener(_performanceStatusChanged);
    config.route.forwardPerformance?.removeStatusListener(_performanceStatusChanged);
    super.dispose();
  }

  void _performanceStatusChanged(PerformanceStatus status) {
    setState(() {
      // The performances' states are our build state, and they changed already.
    });
  }

  Widget build(BuildContext context) {
    Widget contents = new PageStorage(
      key: config.route._subtreeKey,
      bucket: config.route._storageBucket,
      child: new _ModalScopeStatus(
        route: config.route,
        isCurrent: config.route.isCurrent,
        child: config.route.buildPage(context, config.route.performance, config.route.forwardPerformance)
      )
    );
    if (config.route.offstage) {
      contents = new OffStage(child: contents);
    } else {
      contents = new Focus(
        key: new GlobalObjectKey(config.route),
        child: new IgnorePointer(
          ignoring: config.route.performance?.status == PerformanceStatus.reverse,
          child: config.route.buildTransitions(
            context,
            config.route.performance,
            config.route.forwardPerformance,
            contents
          )
        )
      );
    }
    contents = new RepaintBoundary(child: contents);
    ModalPosition position = config.route.getPosition(context);
    if (position == null)
      return contents;
    return new Positioned(
      top: position.top,
      right: position.right,
      bottom: position.bottom,
      left: position.left,
      child: contents
    );
  }
}

class ModalPosition {
  const ModalPosition({ this.top, this.right, this.bottom, this.left });
  final double top;
  final double right;
  final double bottom;
  final double left;
}

abstract class ModalRoute<T> extends TransitionRoute<T> with LocalHistoryRoute<T> {
  ModalRoute({
    Completer<T> completer,
    this.settings: const RouteSettings()
  }) : super.explicit(completer, null);

  // The API for general users of this class

  final RouteSettings settings;

  static ModalRoute of(BuildContext context) {
    _ModalScopeStatus widget = context.inheritFromWidgetOfType(_ModalScopeStatus);
    return widget?.route;
  }


  // The API for subclasses to override - used by _ModalScope

  ModalPosition getPosition(BuildContext context) => null;
  Widget buildPage(BuildContext context, PerformanceView performance, PerformanceView forwardPerformance);
  Widget buildTransitions(BuildContext context, PerformanceView performance, PerformanceView forwardPerformance, Widget child) {
    return child;
  }


  // The API for subclasses to override - used by this class

  /// Whether you can dismiss this route by tapping the modal barrier.
  bool get barrierDismissable;
  /// The color to use for the modal barrier. If this is null, the barrier will
  /// be transparent.
  Color get barrierColor;


  // The API for _ModalScope and HeroController

  bool get offstage => _offstage;
  bool _offstage = false;
  void set offstage (bool value) {
    if (_offstage == value)
      return;
    _offstage = value;
    _scopeKey.currentState?.setState(() {
      // _offstage is the value we're setting, but since there might not be a
      // state, we set it outside of this callback (which will only be called if
      // there's a state currently built).
      // _scopeKey is the key for the _ModalScope built in _buildModalScope().
      // When we mark that state dirty, it'll rebuild itself, and use our
      // offstage (via their config.route.offstage) when building.
    });
  }

  BuildContext get subtreeContext => _subtreeKey.currentContext;


  // Internals

  final GlobalKey<_ModalScopeState> _scopeKey = new GlobalKey<_ModalScopeState>();
  final GlobalKey _subtreeKey = new GlobalKey();
  final PageStorageBucket _storageBucket = new PageStorageBucket();

  Widget _buildModalBarrier(BuildContext context) {
    Widget barrier;
    if (barrierColor != null) {
      assert(barrierColor != _kTransparent);
      barrier = new AnimatedModalBarrier(
        color: new AnimatedColorValue(_kTransparent, end: barrierColor, curve: Curves.ease),
        performance: performance,
        dismissable: barrierDismissable
      );
    } else {
      barrier = new ModalBarrier(dismissable: barrierDismissable);
    }
    assert(performance.status != PerformanceStatus.dismissed);
    return new IgnorePointer(
      ignoring: performance.status == PerformanceStatus.reverse,
      child: barrier
    );
  }

  Widget _buildModalScope(BuildContext context) {
    return new _ModalScope(
      key: _scopeKey,
      route: this
      // calls buildTransitions() and buildPage(), defined above
    );
  }

  List<WidgetBuilder> get builders => <WidgetBuilder>[
    _buildModalBarrier,
    _buildModalScope
  ];

  String toString() => '$runtimeType($settings, performance: $_performance)';
}

/// A modal route that overlays a widget over the current route.
abstract class PopupRoute<T> extends ModalRoute<T> {
  PopupRoute({ Completer<T> completer }) : super(completer: completer);
  bool get opaque => false;
  void didChangeNext(Route nextRoute) {
    assert(nextRoute is! PageRoute);
    super.didChangeNext(nextRoute);
  }
}
