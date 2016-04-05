// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/rendering.dart';

import 'debug.dart';
import 'framework.dart';

export 'package:flutter/rendering.dart' show
    FixedColumnWidth,
    FlexColumnWidth,
    FractionColumnWidth,
    IntrinsicColumnWidth,
    MaxColumnWidth,
    MinColumnWidth,
    TableBorder,
    TableCellVerticalAlignment,
    TableColumnWidth;

class TableRow {
  const TableRow({ this.key, this.decoration, this.children });
  final LocalKey key;
  final Decoration decoration;
  final List<Widget> children;
}

class _TableElementRow {
  const _TableElementRow({ this.key, this.children });
  final LocalKey key;
  final List<Element> children;
}

/// Uses the table layout algorithm for its children.
///
/// For details about the table layout algorithm, see [RenderTable].
/// To control the alignment of children, see [TableCell].
class Table extends RenderObjectWidget {
  Table({
    Key key,
    List<TableRow> children: const <TableRow>[],
    this.columnWidths,
    this.defaultColumnWidth: const FlexColumnWidth(1.0),
    this.border,
    this.defaultVerticalAlignment: TableCellVerticalAlignment.top,
    this.textBaseline
  }) : children = children,
       _rowDecorations = children.any((TableRow row) => row.decoration != null)
                         ? children.map/*<Decoration>*/((TableRow row) => row.decoration).toList()
                         : null,
       super(key: key) {
    assert(children != null);
    assert(defaultColumnWidth != null);
    assert(defaultVerticalAlignment != null);
    assert(() {
      List<Widget> flatChildren = children.expand((TableRow row) => row.children).toList(growable: false);
      return !debugChildrenHaveDuplicateKeys(this, flatChildren);
    });
    assert(!children.any((TableRow row1) => row1.key != null && children.any((TableRow row2) => row1 != row2 && row1.key == row2.key)));
  }

  final List<TableRow> children;
  final Map<int, TableColumnWidth> columnWidths;
  final TableColumnWidth defaultColumnWidth;
  final TableBorder border;
  final TableCellVerticalAlignment defaultVerticalAlignment;
  final TextBaseline textBaseline;

  final List<Decoration> _rowDecorations;

  @override
  _TableElement createElement() => new _TableElement(this);

  @override
  RenderTable createRenderObject(BuildContext context) {
    return new RenderTable(
      columns: children.length > 0 ? children[0].children.length : 0,
      rows: children.length,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      border: border,
      rowDecorations: _rowDecorations,
      defaultVerticalAlignment: defaultVerticalAlignment,
      textBaseline: textBaseline
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTable renderObject) {
    assert(renderObject.columns == (children.length > 0 ? children[0].children.length : 0));
    assert(renderObject.rows == children.length);
    renderObject
      ..columnWidths = columnWidths
      ..defaultColumnWidth = defaultColumnWidth
      ..border = border
      ..rowDecorations = _rowDecorations
      ..defaultVerticalAlignment = defaultVerticalAlignment
      ..textBaseline = textBaseline;
  }
}

class _TableElement extends RenderObjectElement {
  _TableElement(Table widget) : super(widget);

  @override
  Table get widget => super.widget;

  @override
  RenderTable get renderObject => super.renderObject;

  // This class ignores the child's slot entirely.
  // Instead of doing incremental updates to the child list, it replaces the entire list each frame.

  List<_TableElementRow> _children = const<_TableElementRow>[];

  bool _debugWillReattachChildren = false;

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    assert(!_debugWillReattachChildren);
    assert(() { _debugWillReattachChildren = true; return true; });
    _children = widget.children.map((TableRow row) {
      return new _TableElementRow(
        key: row.key,
        children: row.children.map((Widget child) => inflateWidget(child, null)).toList(growable: false)
      );
    }).toList(growable: false);
    assert(() { _debugWillReattachChildren = false; return true; });
    _updateRenderObjectChildren();
  }

  @override
  void insertChildRenderObject(RenderObject child, Element slot) {
    assert(_debugWillReattachChildren);
    renderObject.setupParentData(child);
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slot) {
    assert(_debugWillReattachChildren);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    assert(_debugWillReattachChildren);
    TableCellParentData childParentData = child.parentData;
    renderObject.setChild(childParentData.x, childParentData.y, null);
  }

  final Set<Element> _detachedChildren = new HashSet<Element>();

  @override
  void update(Table newWidget) {
    assert(!_debugWillReattachChildren);
    assert(() { _debugWillReattachChildren = true; return true; });
    Map<LocalKey, List<Element>> oldKeyedRows = new Map<LocalKey, List<Element>>.fromIterable(
      _children.where((_TableElementRow row) => row.key != null),
      key:   (_TableElementRow row) => row.key,
      value: (_TableElementRow row) => row.children
    );
    Iterator<_TableElementRow> oldUnkeyedRows = _children.where((_TableElementRow row) => row.key == null).iterator;
    List<_TableElementRow> newChildren = <_TableElementRow>[];
    Set<List<Element>> taken = new Set<List<Element>>();
    for (TableRow row in newWidget.children) {
      List<Element> oldChildren;
      if (row.key != null && oldKeyedRows.containsKey(row.key)) {
        oldChildren = oldKeyedRows[row.key];
        taken.add(oldChildren);
      } else if (row.key == null && oldUnkeyedRows.moveNext()) {
        oldChildren = oldUnkeyedRows.current.children;
      } else {
        oldChildren = const <Element>[];
      }
      newChildren.add(new _TableElementRow(
        key: row.key,
        children: updateChildren(oldChildren, row.children, detachedChildren: _detachedChildren)
      ));
    }
    while (oldUnkeyedRows.moveNext())
      updateChildren(oldUnkeyedRows.current.children, const <Widget>[], detachedChildren: _detachedChildren);
    for (List<Element> oldChildren in oldKeyedRows.values.where((List<Element> list) => !taken.contains(list)))
      updateChildren(oldChildren, const <Widget>[], detachedChildren: _detachedChildren);
    assert(() { _debugWillReattachChildren = false; return true; });
    _children = newChildren;
    _updateRenderObjectChildren();
    _detachedChildren.clear();
    super.update(newWidget);
    assert(widget == newWidget);
  }

  void _updateRenderObjectChildren() {
    assert(renderObject != null);
    renderObject.setFlatChildren(
      _children.length > 0 ? _children[0].children.length : 0,
      _children.expand((_TableElementRow row) => row.children.map((Element child) => child.renderObject)).toList()
    );
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (Element child in _children.expand((_TableElementRow row) => row.children)) {
      if (!_detachedChildren.contains(child))
        visitor(child);
    }
  }

  @override
  bool detachChild(Element child) {
    _detachedChildren.add(child);
    deactivateChild(child);
    return true;
  }
}

class TableCell extends ParentDataWidget<Table> {
  TableCell({ Key key, this.verticalAlignment, Widget child })
    : super(key: key, child: child);

  final TableCellVerticalAlignment verticalAlignment;

  @override
  void applyParentData(RenderObject renderObject) {
    final TableCellParentData parentData = renderObject.parentData;
    if (parentData.verticalAlignment != verticalAlignment) {
      parentData.verticalAlignment = verticalAlignment;
      AbstractNode targetParent = renderObject.parent;
      if (targetParent is RenderObject)
        targetParent.markNeedsLayout();
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('verticalAlignment: $verticalAlignment');
  }
}
