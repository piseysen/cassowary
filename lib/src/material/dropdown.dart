// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'icon.dart';
import 'icons.dart';
import 'ink_well.dart';
import 'shadows.dart';
import 'theme.dart';
import 'material.dart';

const Duration _kDropDownMenuDuration = const Duration(milliseconds: 300);
const double _kMenuItemHeight = 48.0;
const EdgeInsets _kMenuHorizontalPadding = const EdgeInsets.only(left: 36.0, right: 36.0);
const double _kBaselineOffsetFromBottom = 20.0;
const Border _kDropDownUnderline = const Border(bottom: const BorderSide(color: const Color(0xFFBDBDBD), width: 2.0));

class _DropDownMenuPainter extends CustomPainter {
  const _DropDownMenuPainter({
    this.color,
    this.elevation,
    this.menuTop,
    this.menuBottom,
    this.renderBox
  });

  final Color color;
  final int elevation;
  final double menuTop;
  final double menuBottom;
  final RenderBox renderBox;

  @override
  void paint(Canvas canvas, Size size) {
    final BoxPainter painter = new BoxDecoration(
      backgroundColor: color,
      borderRadius: 2.0,
      boxShadow: elevationToShadow[elevation]
    ).createBoxPainter();

    double top = renderBox.globalToLocal(new Point(0.0, menuTop)).y;
    double bottom = renderBox.globalToLocal(new Point(0.0, menuBottom)).y;
    painter.paint(canvas, new Rect.fromLTRB(0.0, top, size.width, bottom));
  }

  @override
  bool shouldRepaint(_DropDownMenuPainter oldPainter) {
    return oldPainter.color != color
        || oldPainter.elevation != elevation
        || oldPainter.menuTop != menuTop
        || oldPainter.menuBottom != menuBottom
        || oldPainter.renderBox != renderBox;
  }
}

class _DropDownMenu<T> extends StatusTransitionWidget {
  _DropDownMenu({
    Key key,
    _DropDownRoute<T> route
  }) : route = route, super(key: key, animation: route.animation);

  final _DropDownRoute<T> route;

  @override
  Widget build(BuildContext context) {
    // The menu is shown in three stages (unit timing in brackets):
    // [0s - 0.25s] - Fade in a rect-sized menu container with the selected item.
    // [0.25s - 0.5s] - Grow the otherwise empty menu container from the center
    //   until it's big enough for as many items as we're going to show.
    // [0.5s - 1.0s] Fade in the remaining visible items from top to bottom.
    //
    // When the menu is dismissed we just fade the entire thing out
    // in the first 0.25s.

    final double unit = 0.5 / (route.items.length + 1.5);
    final List<Widget> children = <Widget>[];
    for (int itemIndex = 0; itemIndex < route.items.length; ++itemIndex) {
      CurvedAnimation opacity;
      if (itemIndex == route.selectedIndex) {
        opacity = new CurvedAnimation(parent: route.animation, curve: const Interval(0.0, 0.001), reverseCurve: const Interval(0.75, 1.0));
      } else {
        final double start = (0.5 + (itemIndex + 1) * unit).clamp(0.0, 1.0);
        final double end = (start + 1.5 * unit).clamp(0.0, 1.0);
        opacity = new CurvedAnimation(parent: route.animation, curve: new Interval(start, end), reverseCurve: const Interval(0.75, 1.0));
      }
      children.add(new FadeTransition(
        opacity: opacity,
        child: new InkWell(
          child: new Container(
            padding: _kMenuHorizontalPadding,
            child: route.items[itemIndex]
          ),
          onTap: () => Navigator.pop(
            context,
            new _DropDownRouteResult<T>(route.items[itemIndex].value)
          )
        )
      ));
    }

    final CurvedAnimation opacity = new CurvedAnimation(
      parent: route.animation,
      curve: const Interval(0.0, 0.25),
      reverseCurve: const Interval(0.75, 1.0)
    );

    final CurvedAnimation resize = new CurvedAnimation(
      parent: route.animation,
      curve: const Interval(0.25, 0.5),
      reverseCurve: const Interval(0.0, 0.001)
    );

    final Tween<double> menuTop = new Tween<double>(
      begin: route.rect.top,
      end: route.rect.top - route.selectedIndex * route.rect.height
    );
    final Tween<double> menuBottom = new Tween<double>(
      begin: route.rect.bottom,
      end: menuTop.end + route.items.length * route.rect.height
    );

    Widget child = new Material(
      type: MaterialType.transparency,
      child: new Block(children: children)
    );
    return new FadeTransition(
      opacity: opacity,
      child: new AnimatedBuilder(
        animation: resize,
        builder: (BuildContext context, Widget child) {
          return new CustomPaint(
            painter: new _DropDownMenuPainter(
              color: Theme.of(context).canvasColor,
              elevation: route.elevation,
              menuTop: menuTop.evaluate(resize),
              menuBottom: menuBottom.evaluate(resize),
              renderBox: context.findRenderObject()
            ),
            child: child
          );
        },
        child: child
      )
    );
  }
}

// We box the return value so that the return value can be null. Otherwise,
// canceling the route (which returns null) would get confused with actually
// returning a real null value.
class _DropDownRouteResult<T> {
  const _DropDownRouteResult(this.result);

  final T result;

  @override
  bool operator ==(dynamic other) {
    if (other is! _DropDownRouteResult<T>)
      return false;
    final _DropDownRouteResult<T> typedOther = other;
    return result == typedOther.result;
  }

  @override
  int get hashCode => result.hashCode;
}

class _DropDownRoute<T> extends PopupRoute<_DropDownRouteResult<T>> {
  _DropDownRoute({
    Completer<_DropDownRouteResult<T>> completer,
    this.items,
    this.selectedIndex,
    this.rect,
    this.elevation: 8
  }) : super(completer: completer);

  final List<DropDownMenuItem<T>> items;
  final int selectedIndex;
  final Rect rect;
  final int elevation;

  @override
  Duration get transitionDuration => _kDropDownMenuDuration;

  @override
  bool get barrierDismissable => true;

  @override
  Color get barrierColor => null;

  @override
  ModalPosition getPosition(BuildContext context) {
    RenderBox overlayBox = Overlay.of(context).context.findRenderObject();
    assert(overlayBox != null); // can't be null; routes get inserted by Navigator which has its own Overlay
    Size overlaySize = overlayBox.size;
    RelativeRect menuRect = new RelativeRect.fromSize(rect, overlaySize);
    return new ModalPosition(
      top: menuRect.top - selectedIndex * rect.height,
      left: menuRect.left,
      right: menuRect.right
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> forwardAnimation) {
    return new _DropDownMenu<T>(route: this);
  }
}

class DropDownMenuItem<T> extends StatelessWidget {
  DropDownMenuItem({
    Key key,
    this.value,
    this.child
  }) : super(key: key);

  final Widget child;
  final T value;

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: _kMenuItemHeight,
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 6.0),
      child: new DefaultTextStyle(
        style: Theme.of(context).textTheme.subhead,
        child: new Baseline(
          baseline: _kMenuItemHeight - _kBaselineOffsetFromBottom,
          child: child
        )
      )
    );
  }
}

class DropDownButton<T> extends StatefulWidget {
  DropDownButton({
    Key key,
    this.items,
    this.value,
    this.onChanged,
    this.elevation: 8
  }) : super(key: key) {
    assert(items.where((DropDownMenuItem<T> item) => item.value == value).length == 1);
  }

  final List<DropDownMenuItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final int elevation;

  @override
  _DropDownButtonState<T> createState() => new _DropDownButtonState<T>();
}

class _DropDownButtonState<T> extends State<DropDownButton<T>> {
  final GlobalKey indexedStackKey = new GlobalKey(debugLabel: 'DropDownButton.IndexedStack');

  @override
  void initState() {
    super.initState();
    _updateSelectedIndex();
    assert(_selectedIndex != null);
  }

  @override
  void didUpdateConfig(DropDownButton<T> oldConfig) {
    if (config.items[_selectedIndex].value != config.value)
      _updateSelectedIndex();
  }

  int _selectedIndex;

  void _updateSelectedIndex() {
    for (int itemIndex = 0; itemIndex < config.items.length; itemIndex++) {
      if (config.items[itemIndex].value == config.value) {
        _selectedIndex = itemIndex;
        return;
      }
    }
  }

  void _handleTap() {
    final RenderBox renderBox = indexedStackKey.currentContext.findRenderObject();
    final Rect rect = renderBox.localToGlobal(Point.origin) & renderBox.size;
    final Completer<_DropDownRouteResult<T>> completer = new Completer<_DropDownRouteResult<T>>();
    Navigator.push(context, new _DropDownRoute<T>(
      completer: completer,
      items: config.items,
      selectedIndex: _selectedIndex,
      rect: _kMenuHorizontalPadding.inflateRect(rect),
      elevation: config.elevation
    ));
    completer.future.then((_DropDownRouteResult<T> newValue) {
      if (!mounted || newValue == null)
        return;
      if (config.onChanged != null)
        config.onChanged(newValue.result);
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    return new GestureDetector(
      onTap: _handleTap,
      child: new Container(
        decoration: new BoxDecoration(border: _kDropDownUnderline),
        child: new Row(
          children: <Widget>[
            new IndexedStack(
              children: config.items,
              key: indexedStackKey,
              index: _selectedIndex,
              alignment: const FractionalOffset(0.5, 0.0)
            ),
            new Container(
              child: new Icon(icon: Icons.arrow_drop_down, size: 36.0),
              padding: const EdgeInsets.only(top: 6.0)
            )
          ],
          mainAxisAlignment: MainAxisAlignment.collapse
        )
      )
    );
  }
}
