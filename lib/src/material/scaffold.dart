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

const double _kFloatingActionButtonMargin = 16.0; // TODO(hmuller): should be device dependent

enum _Child { body, toolBar, bottomSheet, snackBar, floatingActionButton }

class _ScaffoldLayout extends MultiChildLayoutDelegate {
  void performLayout(Size size, BoxConstraints constraints) {

    // This part of the layout has the same effect as putting the toolbar and
    // body in a column and making the body flexible. What's different is that
    // in this case the toolbar appears -after- the body in the stacking order,
    // so the toolbar's shadow is drawn on top of the body.

    final BoxConstraints toolBarConstraints = constraints.loosen().tightenWidth(size.width);
    Size toolBarSize = Size.zero;

    if (isChild(_Child.toolBar)) {
      toolBarSize = layoutChild(_Child.toolBar, toolBarConstraints);
      positionChild(_Child.toolBar, Point.origin);
    }

    if (isChild(_Child.body)) {
      final double bodyHeight = size.height - toolBarSize.height;
      final BoxConstraints bodyConstraints = toolBarConstraints.tightenHeight(bodyHeight);
      layoutChild(_Child.body, bodyConstraints);
      positionChild(_Child.body, new Point(0.0, toolBarSize.height));
    }

    // The BottomSheet and the SnackBar are anchored to the bottom of the parent,
    // they're as wide as the parent and are given their intrinsic height.
    // If all three elements are present then either the center of the FAB straddles
    // the top edge of the BottomSheet or the bottom of the FAB is
    // _kFloatingActionButtonMargin above the SnackBar, whichever puts the FAB
    // the farthest above the bottom of the parent. If only the FAB is has a
    // non-zero height then it's inset from the parent's right and bottom edges
    // by _kFloatingActionButtonMargin.

    final BoxConstraints fullWidthConstraints = constraints.loosen().tightenWidth(size.width);
    Size bottomSheetSize = Size.zero;
    Size snackBarSize = Size.zero;

    if (isChild(_Child.bottomSheet)) {
      bottomSheetSize = layoutChild(_Child.bottomSheet, fullWidthConstraints);
      positionChild(_Child.bottomSheet, new Point((size.width - bottomSheetSize.width) / 2.0, size.height - bottomSheetSize.height));
    }

    if (isChild(_Child.snackBar)) {
      snackBarSize = layoutChild(_Child.snackBar, fullWidthConstraints);
      positionChild(_Child.snackBar, new Point(0.0, size.height - snackBarSize.height));
    }

    if (isChild(_Child.floatingActionButton)) {
      final Size fabSize = layoutChild(_Child.floatingActionButton, constraints.loosen());
      final double fabX = size.width - fabSize.width - _kFloatingActionButtonMargin;
      double fabY = size.height - fabSize.height - _kFloatingActionButtonMargin;
      if (snackBarSize.height > 0.0)
        fabY = math.min(fabY, size.height - snackBarSize.height - fabSize.height - _kFloatingActionButtonMargin);
      if (bottomSheetSize.height > 0.0)
        fabY = math.min(fabY, size.height - bottomSheetSize.height - fabSize.height / 2.0);
      positionChild(_Child.floatingActionButton, new Point(fabX, fabY));
    }
  }
}

final _ScaffoldLayout _scaffoldLayout = new _ScaffoldLayout();

class Scaffold extends StatefulComponent {
  Scaffold({
    Key key,
    this.toolBar,
    this.body,
    this.floatingActionButton
  }) : super(key: key);

  final ToolBar toolBar;
  final Widget body;
  final Widget floatingActionButton;

  static ScaffoldState of(BuildContext context) => context.ancestorStateOfType(ScaffoldState);

  ScaffoldState createState() => new ScaffoldState();
}

class ScaffoldState extends State<Scaffold> {

  // SNACKBAR API

  Queue<SnackBar> _snackBars = new Queue<SnackBar>();
  Performance _snackBarPerformance;
  Timer _snackBarTimer;

  void showSnackBar(SnackBar snackbar) {
    _snackBarPerformance ??= SnackBar.createPerformance()
      ..addStatusListener(_handleSnackBarStatusChange);
    if (_snackBars.isEmpty) {
      assert(_snackBarPerformance.isDismissed);
      _snackBarPerformance.forward();
    }
    setState(() {
      _snackBars.addLast(snackbar.withPerformance(_snackBarPerformance));
    });
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
    _snackBarPerformance.reverse();
    _snackBarTimer = null;
  }


  // PERSISTENT BOTTOM SHEET API

  List<Widget> _dismissedBottomSheets;
  BottomSheetController _currentBottomSheet;

  BottomSheetController showBottomSheet(WidgetBuilder builder) {
    if (_currentBottomSheet != null) {
      _currentBottomSheet.close();
      assert(_currentBottomSheet == null);
    }
    Completer completer = new Completer();
    GlobalKey<_PersistentBottomSheetState> bottomSheetKey = new GlobalKey<_PersistentBottomSheetState>();
    Performance performance = BottomSheet.createPerformance()
      ..forward();
    _PersistentBottomSheet bottomSheet;
    Route route = new StateRoute(
      onPop: () {
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
        Navigator.of(context).remove(route);
      },
      onDismissed: () {
        assert(_dismissedBottomSheets != null);
        setState(() {
          _dismissedBottomSheets.remove(bottomSheet);
        });
      },
      builder: builder
    );
    Navigator.of(context).push(route);
    setState(() {
      _currentBottomSheet = new BottomSheetController._(
        bottomSheet,
        completer.future,
        () => Navigator.of(context).remove(route),
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

  Widget build(BuildContext context) {
    final Widget paddedToolBar = config.toolBar?.withPadding(new EdgeDims.only(top: ui.window.padding.top));
    final Widget materialBody = config.body != null ? new Material(child: config.body) : null;

    if (_snackBars.length > 0) {
      ModalRoute route = ModalRoute.of(context);
      if (route == null || route.isCurrent) {
        if (_snackBarPerformance.isCompleted && _snackBarTimer == null)
          _snackBarTimer = new Timer(_snackBars.first.duration, _hideSnackBar);
      } else {
        _snackBarTimer?.cancel();
        _snackBarTimer = null;
      }
    }

    final List<LayoutId>children = new List<LayoutId>();
    _addIfNonNull(children, materialBody, _Child.body);
    _addIfNonNull(children, paddedToolBar, _Child.toolBar);

    if (_currentBottomSheet != null ||
        (_dismissedBottomSheets != null && _dismissedBottomSheets.isNotEmpty)) {
      List<Widget> bottomSheets = <Widget>[];
      if (_dismissedBottomSheets != null && _dismissedBottomSheets.isNotEmpty)
        bottomSheets.addAll(_dismissedBottomSheets);
      if (_currentBottomSheet != null)
        bottomSheets.add(_currentBottomSheet._widget);
      Widget stack = new Stack(
        bottomSheets,
        alignment: const FractionalOffset(0.5, 1.0) // bottom-aligned, centered
      );
      _addIfNonNull(children, stack, _Child.bottomSheet);
    }

    if (_snackBars.isNotEmpty)
      _addIfNonNull(children, _snackBars.first, _Child.snackBar);

    _addIfNonNull(children, config.floatingActionButton, _Child.floatingActionButton);

    return new CustomMultiChildLayout(children, delegate: _scaffoldLayout);
  }

}

class BottomSheetController {
  const BottomSheetController._(this._widget, this.closed, this.close, this.setState);
  final Widget _widget;
  final Future closed;
  final VoidCallback close; // call this to close the bottom sheet
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

  double _childHeight;
  void _updateChildHeight(Size newSize) {
    setState(() {
      _childHeight = newSize.height;
    });
  }

  Widget build(BuildContext context) {
    return new AlignTransition(
      performance: config.performance,
      alignment: new AnimatedValue<FractionalOffset>(const FractionalOffset(0.0, 0.0)),
      heightFactor: new AnimatedValue<double>(0.0, end: 1.0),
      child: new BottomSheet(
        performance: config.performance,
        onClosing: config.onClosing,
        childHeight: _childHeight,
        builder: (BuildContext context) => new SizeObserver(child: config.builder(context), onSizeChanged: _updateChildHeight)
      )
    );
  }

}
