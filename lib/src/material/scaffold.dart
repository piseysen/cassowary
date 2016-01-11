// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bottom_sheet.dart';
import 'material.dart';
import 'snack_bar.dart';
import 'tool_bar.dart';
import 'drawer.dart';
import 'icon_button.dart';

const double _kFloatingActionButtonMargin = 16.0; // TODO(hmuller): should be device dependent

enum _Child {
  body,
  toolBar,
  bottomSheet,
  snackBar,
  floatingActionButton,
  drawer,
}

class _ScaffoldLayout extends MultiChildLayoutDelegate {
  void performLayout(Size size, BoxConstraints constraints) {

    BoxConstraints looseConstraints = constraints.loosen();

    // This part of the layout has the same effect as putting the toolbar and
    // body in a column and making the body flexible. What's different is that
    // in this case the toolbar appears -after- the body in the stacking order,
    // so the toolbar's shadow is drawn on top of the body.

    final BoxConstraints fullWidthConstraints = looseConstraints.tighten(width: size.width);
    Size toolBarSize = Size.zero;

    if (isChild(_Child.toolBar)) {
      toolBarSize = layoutChild(_Child.toolBar, fullWidthConstraints);
      positionChild(_Child.toolBar, Offset.zero);
    }

    if (isChild(_Child.body)) {
      final double bodyHeight = size.height - toolBarSize.height;
      final BoxConstraints bodyConstraints = fullWidthConstraints.tighten(height: bodyHeight);
      layoutChild(_Child.body, bodyConstraints);
      positionChild(_Child.body, new Offset(0.0, toolBarSize.height));
    }

    // The BottomSheet and the SnackBar are anchored to the bottom of the parent,
    // they're as wide as the parent and are given their intrinsic height.
    // If all three elements are present then either the center of the FAB straddles
    // the top edge of the BottomSheet or the bottom of the FAB is
    // _kFloatingActionButtonMargin above the SnackBar, whichever puts the FAB
    // the farthest above the bottom of the parent. If only the FAB is has a
    // non-zero height then it's inset from the parent's right and bottom edges
    // by _kFloatingActionButtonMargin.

    Size bottomSheetSize = Size.zero;
    Size snackBarSize = Size.zero;

    if (isChild(_Child.bottomSheet)) {
      bottomSheetSize = layoutChild(_Child.bottomSheet, fullWidthConstraints);
      positionChild(_Child.bottomSheet, new Offset((size.width - bottomSheetSize.width) / 2.0, size.height - bottomSheetSize.height));
    }

    if (isChild(_Child.snackBar)) {
      snackBarSize = layoutChild(_Child.snackBar, fullWidthConstraints);
      positionChild(_Child.snackBar, new Offset(0.0, size.height - snackBarSize.height));
    }

    if (isChild(_Child.floatingActionButton)) {
      final Size fabSize = layoutChild(_Child.floatingActionButton, looseConstraints);
      final double fabX = size.width - fabSize.width - _kFloatingActionButtonMargin;
      double fabY = size.height - fabSize.height - _kFloatingActionButtonMargin;
      if (snackBarSize.height > 0.0)
        fabY = math.min(fabY, size.height - snackBarSize.height - fabSize.height - _kFloatingActionButtonMargin);
      if (bottomSheetSize.height > 0.0)
        fabY = math.min(fabY, size.height - bottomSheetSize.height - fabSize.height / 2.0);
      positionChild(_Child.floatingActionButton, new Offset(fabX, fabY));
    }

    if (isChild(_Child.drawer)) {
      layoutChild(_Child.drawer, new BoxConstraints.tight(size));
      positionChild(_Child.drawer, Offset.zero);
    }
  }

  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => false;
}

class Scaffold extends StatefulComponent {
  Scaffold({
    Key key,
    this.toolBar,
    this.body,
    this.floatingActionButton,
    this.drawer
  }) : super(key: key);

  final ToolBar toolBar;
  final Widget body;
  final Widget floatingActionButton;
  final Widget drawer;

  /// The state from the closest instance of this class that encloses the given context.
  static ScaffoldState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<ScaffoldState>());

  ScaffoldState createState() => new ScaffoldState();
}

class ScaffoldState extends State<Scaffold> {

  // DRAWER API

  final GlobalKey<DrawerControllerState> _drawerKey = new GlobalKey<DrawerControllerState>();

  void openDrawer() {
    _drawerKey.currentState.open();
  }

  // SNACKBAR API

  Queue<ScaffoldFeatureController<SnackBar>> _snackBars = new Queue<ScaffoldFeatureController<SnackBar>>();
  Performance _snackBarPerformance;
  Timer _snackBarTimer;

  ScaffoldFeatureController showSnackBar(SnackBar snackbar) {
    _snackBarPerformance ??= SnackBar.createPerformanceController()
      ..addStatusListener(_handleSnackBarStatusChange);
    if (_snackBars.isEmpty) {
      assert(_snackBarPerformance.isDismissed);
      _snackBarPerformance.forward();
    }
    ScaffoldFeatureController<SnackBar> controller;
    controller = new ScaffoldFeatureController<SnackBar>._(
      // We provide a fallback key so that if back-to-back snackbars happen to
      // match in structure, material ink splashes and highlights don't survive
      // from one to the next.
      snackbar.withPerformance(_snackBarPerformance, fallbackKey: new UniqueKey()),
      new Completer(),
      () {
        assert(_snackBars.first == controller);
        _hideSnackBar();
      },
      null // SnackBar doesn't use a builder function so setState() wouldn't rebuild it
    );
    setState(() {
      _snackBars.addLast(controller);
    });
    return controller;
  }

  void _handleSnackBarStatusChange(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.dismissed:
        assert(_snackBars.isNotEmpty);
        setState(() {
          _snackBars.removeFirst();
        });
        if (_snackBars.isNotEmpty)
          _snackBarPerformance.forward();
        break;
      case PerformanceStatus.completed:
        setState(() {
          assert(_snackBarTimer == null);
          // build will create a new timer if necessary to dismiss the snack bar
        });
        break;
      case PerformanceStatus.forward:
      case PerformanceStatus.reverse:
        break;
    }
  }

  void _hideSnackBar() {
    assert(_snackBarPerformance.status == PerformanceStatus.forward ||
           _snackBarPerformance.status == PerformanceStatus.completed);
    _snackBars.first._completer.complete();
    _snackBarPerformance.reverse();
    _snackBarTimer = null;
  }


  // PERSISTENT BOTTOM SHEET API

  List<Widget> _dismissedBottomSheets;
  ScaffoldFeatureController _currentBottomSheet;

  ScaffoldFeatureController showBottomSheet(WidgetBuilder builder) {
    if (_currentBottomSheet != null) {
      _currentBottomSheet.close();
      assert(_currentBottomSheet == null);
    }
    Completer completer = new Completer();
    GlobalKey<_PersistentBottomSheetState> bottomSheetKey = new GlobalKey<_PersistentBottomSheetState>();
    Performance performance = BottomSheet.createPerformanceController()
      ..forward();
    _PersistentBottomSheet bottomSheet;
    LocalHistoryEntry entry = new LocalHistoryEntry(
      onRemove: () {
        assert(_currentBottomSheet._widget == bottomSheet);
        assert(bottomSheetKey.currentState != null);
        bottomSheetKey.currentState.close();
        _dismissedBottomSheets ??= <Widget>[];
        _dismissedBottomSheets.add(bottomSheet);
        _currentBottomSheet = null;
        completer.complete();
      }
    );
    bottomSheet = new _PersistentBottomSheet(
      key: bottomSheetKey,
      performance: performance,
      onClosing: () {
        assert(_currentBottomSheet._widget == bottomSheet);
        entry.remove();
      },
      onDismissed: () {
        assert(_dismissedBottomSheets != null);
        setState(() {
          _dismissedBottomSheets.remove(bottomSheet);
        });
      },
      builder: builder
    );
    ModalRoute.of(context).addLocalHistoryEntry(entry);
    setState(() {
      _currentBottomSheet = new ScaffoldFeatureController._(
        bottomSheet,
        completer,
        () => entry.remove(),
        setState
      );
    });
    return _currentBottomSheet;
  }


  // INTERNALS

  void dispose() {
    _snackBarPerformance?.stop();
    _snackBarPerformance = null;
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
    super.dispose();
  }

  void _addIfNonNull(List<LayoutId> children, Widget child, Object childId) {
    if (child != null)
      children.add(new LayoutId(child: child, id: childId));
  }

  bool _shouldShowBackArrow;

  Widget get _modifiedToolBar {
    ToolBar toolBar = config.toolBar;
    if (toolBar == null)
      return null;
    EdgeDims padding = new EdgeDims.only(top: ui.window.padding.top);
    Widget left = toolBar.left;
    if (left == null) {
      if (config.drawer != null) {
        left = new IconButton(
          icon: 'navigation/menu',
          onPressed: openDrawer
        );
      } else {
        _shouldShowBackArrow ??= Navigator.canPop(context);
        if (_shouldShowBackArrow) {
          left = new IconButton(
            icon: 'navigation/arrow_back',
            onPressed: () => Navigator.pop(context)
          );
        }
      }
    }
    return toolBar.copyWith(
      padding: padding,
      left: left
    );
  }

  Widget build(BuildContext context) {
    final Widget materialBody = config.body != null ? new Material(child: config.body) : null;

    if (_snackBars.length > 0) {
      ModalRoute route = ModalRoute.of(context);
      if (route == null || route.isCurrent) {
        if (_snackBarPerformance.isCompleted && _snackBarTimer == null)
          _snackBarTimer = new Timer(_snackBars.first._widget.duration, _hideSnackBar);
      } else {
        _snackBarTimer?.cancel();
        _snackBarTimer = null;
      }
    }

    final List<LayoutId>children = new List<LayoutId>();
    _addIfNonNull(children, materialBody, _Child.body);
    _addIfNonNull(children, _modifiedToolBar, _Child.toolBar);

    if (_currentBottomSheet != null ||
        (_dismissedBottomSheets != null && _dismissedBottomSheets.isNotEmpty)) {
      List<Widget> bottomSheets = <Widget>[];
      if (_dismissedBottomSheets != null && _dismissedBottomSheets.isNotEmpty)
        bottomSheets.addAll(_dismissedBottomSheets);
      if (_currentBottomSheet != null)
        bottomSheets.add(_currentBottomSheet._widget);
      Widget stack = new Stack(
        children: bottomSheets,
        alignment: const FractionalOffset(0.5, 1.0) // bottom-aligned, centered
      );
      _addIfNonNull(children, stack, _Child.bottomSheet);
    }

    if (_snackBars.isNotEmpty)
      _addIfNonNull(children, _snackBars.first._widget, _Child.snackBar);

    _addIfNonNull(children, config.floatingActionButton, _Child.floatingActionButton);

    if (config.drawer != null) {
      children.add(new LayoutId(
        id: _Child.drawer,
        child: new DrawerController(
          key: _drawerKey,
          child: config.drawer
        )
      ));
    }

    return new CustomMultiChildLayout(children: children, delegate: new _ScaffoldLayout());
  }
}

class ScaffoldFeatureController<T extends Widget> {
  const ScaffoldFeatureController._(this._widget, this._completer, this.close, this.setState);
  final T _widget;
  final Completer _completer;
  Future get closed => _completer.future;
  final VoidCallback close; // call this to close the bottom sheet or snack bar
  final StateSetter setState;
}

class _PersistentBottomSheet extends StatefulComponent {
  _PersistentBottomSheet({
    Key key,
    this.performance,
    this.onClosing,
    this.onDismissed,
    this.builder
  }) : super(key: key);

  final Performance performance;
  final VoidCallback onClosing;
  final VoidCallback onDismissed;
  final WidgetBuilder builder;

  _PersistentBottomSheetState createState() => new _PersistentBottomSheetState();
}

class _PersistentBottomSheetState extends State<_PersistentBottomSheet> {

  // We take ownership of the performance given in the first configuration.
  // We also share control of that performance with out BottomSheet widget.

  void initState() {
    super.initState();
    assert(config.performance.status == PerformanceStatus.forward);
    config.performance.addStatusListener(_handleStatusChange);
  }

  void didUpdateConfig(_PersistentBottomSheet oldConfig) {
    super.didUpdateConfig(oldConfig);
    assert(config.performance == oldConfig.performance);
  }

  void dispose() {
    config.performance.stop();
    super.dispose();
  }

  void close() {
    config.performance.reverse();
  }

  void _handleStatusChange(PerformanceStatus status) {
    if (status == PerformanceStatus.dismissed && config.onDismissed != null)
      config.onDismissed();
  }

  Widget build(BuildContext context) {
    return new AlignTransition(
      performance: config.performance,
      alignment: new AnimatedValue<FractionalOffset>(const FractionalOffset(0.0, 0.0)),
      heightFactor: new AnimatedValue<double>(0.0, end: 1.0),
      child: new BottomSheet(
        performance: config.performance,
        onClosing: config.onClosing,
        builder: config.builder
      )
    );
  }

}
