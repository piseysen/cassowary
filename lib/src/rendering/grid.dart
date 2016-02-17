// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'box.dart';
import 'object.dart';
import 'viewport.dart';

bool _debugIsMonotonic(List<double> offsets) {
  bool result = true;
  assert(() {
    double current = 0.0;
    for (double offset in offsets) {
      if (current > offset) {
        result = false;
        break;
      }
      current = offset;
    }
    return true;
  });
  return result;
}

List<double> _generateRegularOffsets(int count, double size) {
  final int length = count + 1;
  final List<double> result = new Float64List(length);
  for (int i = 0; i < length; ++i)
    result[i] = i * size;
  return result;
}

class GridSpecification {
  /// Creates a grid specification from an explicit list of offsets.
  GridSpecification.fromOffsets({
    this.columnOffsets,
    this.rowOffsets,
    this.columnSpacing: 0.0,
    this.rowSpacing: 0.0,
    this.padding: EdgeDims.zero
  }) {
    assert(_debugIsMonotonic(columnOffsets));
    assert(_debugIsMonotonic(rowOffsets));
    assert(columnSpacing != null && columnSpacing >= 0.0);
    assert(rowSpacing != null && rowSpacing >= 0.0);
    assert(padding != null && padding.isNonNegative);
  }

  /// Creates a grid specification containing a certain number of equally sized tiles.
  GridSpecification.fromRegularTiles({
    double tileWidth,
    double tileHeight,
    int columnCount,
    int rowCount,
    this.rowSpacing: 0.0,
    this.columnSpacing: 0.0,
    this.padding: EdgeDims.zero
  }) : columnOffsets = _generateRegularOffsets(columnCount, tileWidth),
       rowOffsets = _generateRegularOffsets(rowCount, tileHeight) {
    assert(_debugIsMonotonic(columnOffsets));
    assert(_debugIsMonotonic(rowOffsets));
    assert(padding != null && padding.isNonNegative);
  }

  /// The offsets of the column boundaries in the grid.
  ///
  /// The first offset is the offset of the left edge of the left-most column
  /// from the left edge of the interior of the grid's padding (0.0 if the padding
  /// is EdgeOffsets.zero). The last offset is the offset of the right edge of
  /// the right-most column from the left edge of the interior of the grid's padding.
  ///
  /// If there are n columns in the grid, there should be n + 1 entries in this
  /// list. The right edge of the last column is defined as columnOffsets(n), i.e.
  /// the left edge of an extra column.
  final List<double> columnOffsets;

  /// The offsets of the row boundaries in the grid.
  ///
  /// The first offset is the offset of the top edge of the top-most row from
  /// the top edge of the interior of the grid's padding (usually if the padding
  /// is EdgeOffsets.zero). The last offset is the offset of the bottom edge of
  /// the bottom-most column from the top edge of the interior of the grid's padding.
  ///
  /// If there are n rows in the grid, there should be n + 1 entries in this
  /// list. The bottom edge of the last row is defined as rowOffsets(n), i.e.
  /// the top edge of an extra row.
  final List<double> rowOffsets;

  /// The vertical distance between rows.
  final double rowSpacing;

  /// The horizontal distance between columns.
  final double columnSpacing;

  /// The interior padding of the grid.
  ///
  /// The grid's size encloses the spaced rows and columns and is then inflated
  /// by the padding.
  final EdgeDims padding;

  /// The size of the grid.
  Size get gridSize => new Size(columnOffsets.last + padding.horizontal, rowOffsets.last + padding.vertical);

  /// The number of columns in this grid.
  int get columnCount => columnOffsets.length - 1;

  /// The number of rows in this grid.
  int get rowCount => rowOffsets.length - 1;
}

/// Where to place a child within a grid.
class GridChildPlacement {
  GridChildPlacement({
    this.column,
    this.row,
    this.columnSpan: 1,
    this.rowSpan: 1
  }) {
    assert(column != null && column >= 0);
    assert(row != null && row >= 0);
    assert(columnSpan != null && columnSpan > 0);
    assert(rowSpan != null && rowSpan > 0);
  }

  /// The column in which to place the child.
  final int column;

  /// The row in which to place the child.
  final int row;

  /// How many columns the child should span.
  final int columnSpan;

  /// How many rows the child should span.
  final int rowSpan;
}

/// An abstract interface to control the layout of a [RenderGrid].
abstract class GridDelegate {
  /// Override this function to control size of the columns and rows.
  GridSpecification getGridSpecification(BoxConstraints constraints, int childCount);

  /// Override this function to control where children are placed in the grid.
  GridChildPlacement getChildPlacement(GridSpecification specification, int index, Object placementData);

  /// Override this method to return true when the children need to be laid out.
  bool shouldRelayout(GridDelegate oldDelegate) => true;

  Size _getGridSize(BoxConstraints constraints, int childCount) {
    return getGridSpecification(constraints, childCount).gridSize;
  }

  /// Returns the minimum width that this grid could be without failing to paint
  /// its contents within itself.
  double getMinIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(_getGridSize(constraints, childCount).width);
  }

  /// Returns the smallest width beyond which increasing the width never
  /// decreases the height.
  double getMaxIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(_getGridSize(constraints, childCount).width);
  }

  /// Return the minimum height that this grid could be without failing to paint
  /// its contents within itself.
  double getMinIntrinsicHeight(BoxConstraints constraints, int childCount) {
    return constraints.constrainHeight(_getGridSize(constraints, childCount).height);
  }

  /// Returns the smallest height beyond which increasing the height never
  /// decreases the width.
  double getMaxIntrinsicHeight(BoxConstraints constraints, int childCount) {
    return constraints.constrainHeight(_getGridSize(constraints, childCount).height);
  }
}

/// A [GridDelegate] the places its children in order throughout the grid.
abstract class GridDelegateWithInOrderChildPlacement extends GridDelegate {
  GridDelegateWithInOrderChildPlacement({
    this.columnSpacing: 0.0,
    this.rowSpacing: 0.0,
    this.padding: EdgeDims.zero
  }) {
    assert(columnSpacing != null && columnSpacing >= 0.0);
    assert(rowSpacing != null && rowSpacing >= 0.0);
    assert(padding != null && padding.isNonNegative);
  }

  /// The horizontal distance between columns.
  final double columnSpacing;

  /// The vertical distance between rows.
  final double rowSpacing;

  // Insets for the entire grid.
  final EdgeDims padding;

  GridChildPlacement getChildPlacement(GridSpecification specification, int index, Object placementData) {
    final int columnCount = specification.columnOffsets.length - 1;
    return new GridChildPlacement(
      column: index % columnCount,
      row: index ~/ columnCount
    );
  }

  bool shouldRelayout(GridDelegateWithInOrderChildPlacement oldDelegate) {
    return columnSpacing != oldDelegate.columnSpacing
      || rowSpacing != oldDelegate.rowSpacing
      || padding != oldDelegate.padding;
  }
}


/// A [GridDelegate] that divides the grid's width evenly amount a fixed number of columns.
class FixedColumnCountGridDelegate extends GridDelegateWithInOrderChildPlacement {
  FixedColumnCountGridDelegate({
    this.columnCount,
    double columnSpacing: 0.0,
    double rowSpacing: 0.0,
    EdgeDims padding: EdgeDims.zero,
    this.tileAspectRatio: 1.0
  }) : super(columnSpacing: columnSpacing, rowSpacing: rowSpacing, padding: padding) {
    assert(columnCount != null && columnCount >= 0);
    assert(tileAspectRatio != null && tileAspectRatio > 0.0);
  }

  /// The number of columns in the grid.
  final int columnCount;

  /// The ratio of the width to the height of each tile in the grid.
  final double tileAspectRatio;

  GridSpecification getGridSpecification(BoxConstraints constraints, int childCount) {
    assert(constraints.maxWidth < double.INFINITY);
    int rowCount = (childCount / columnCount).ceil();
    double tileWidth = math.max(0.0, constraints.maxWidth - padding.horizontal + columnSpacing) / columnCount;
    double tileHeight = tileWidth / tileAspectRatio;
    return new GridSpecification.fromRegularTiles(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      columnCount: columnCount,
      rowCount: rowCount,
      columnSpacing: columnSpacing,
      rowSpacing: rowSpacing,
      padding: padding
    );
  }

  bool shouldRelayout(FixedColumnCountGridDelegate oldDelegate) {
    return columnCount != oldDelegate.columnCount
        || tileAspectRatio != oldDelegate.tileAspectRatio
        || super.shouldRelayout(oldDelegate);
  }

  double getMinIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(0.0);
  }
}

/// A [GridDelegate] that fills the width with a variable number of tiles.
///
/// This delegate will select a tile width that is as large as possible subject
/// to the following conditions:
///
///  - The tile width evenly divides the width of the grid.
///  - The tile width is at most [maxTileWidth].
///
class MaxTileWidthGridDelegate extends GridDelegateWithInOrderChildPlacement {
  MaxTileWidthGridDelegate({
    this.maxTileWidth,
    this.tileAspectRatio: 1.0,
    double columnSpacing: 0.0,
    double rowSpacing: 0.0,
    EdgeDims padding: EdgeDims.zero
  }) : super(columnSpacing: columnSpacing, rowSpacing: rowSpacing, padding: padding) {
    assert(maxTileWidth != null && maxTileWidth >= 0.0);
    assert(tileAspectRatio != null && tileAspectRatio > 0.0);
  }

  /// The maximum width of a tile in the grid.
  final double maxTileWidth;

  /// The ratio of the width to the height of each tile in the grid.
  final double tileAspectRatio;

  GridSpecification getGridSpecification(BoxConstraints constraints, int childCount) {
    assert(constraints.maxWidth < double.INFINITY);
    final double gridWidth = math.max(0.0, constraints.maxWidth - padding.horizontal);
    int columnCount = (gridWidth / maxTileWidth).ceil();
    int rowCount = (childCount / columnCount).ceil();
    double tileWidth = gridWidth / columnCount;
    double tileHeight = tileWidth / tileAspectRatio;
    return new GridSpecification.fromRegularTiles(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      columnCount: columnCount,
      rowCount: rowCount,
      columnSpacing: columnSpacing,
      rowSpacing: rowSpacing,
      padding: padding
    );
  }

  bool shouldRelayout(MaxTileWidthGridDelegate oldDelegate) {
    return maxTileWidth != oldDelegate.maxTileWidth
        || tileAspectRatio != oldDelegate.tileAspectRatio
        || super.shouldRelayout(oldDelegate);
  }

  double getMinIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(0.0);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints, int childCount) {
    return constraints.constrainWidth(maxTileWidth * childCount);
  }
}

/// Parent data for use with [RenderGrid]
class GridParentData extends ContainerBoxParentDataMixin<RenderBox> {
  /// Opaque data passed to the getChildPlacement method of the grid's [GridDelegate].
  Object placementData;

  String toString() => '${super.toString()}; placementData=$placementData';
}

/// Implements the grid layout algorithm
///
/// In grid layout, children are arranged into rows and columns in on a two
/// dimensional grid. The [GridDelegate] determines how to arrange the
/// children on the grid.
///
/// The arrangment of rows and columns in the grid cannot depend on the contents
/// of the tiles in the grid, which makes grid layout most useful for images and
/// card-like layouts rather than for document-like layouts that adjust to the
/// amount of text contained in the tiles.
///
/// Additionally, grid layout materializes all of its children, which makes it
/// most useful for grids containing a moderate number of tiles.
class RenderGrid extends RenderVirtualViewport<GridParentData> {
  RenderGrid({
    List<RenderBox> children,
    GridDelegate delegate,
    int virtualChildBase: 0,
    int virtualChildCount,
    Offset paintOffset: Offset.zero,
    Painter overlayPainter,
    LayoutCallback callback
  }) : _delegate = delegate, _virtualChildBase = virtualChildBase, super(
    virtualChildCount: virtualChildCount,
    paintOffset: paintOffset,
    overlayPainter: overlayPainter,
    callback: callback
  ) {
    assert(delegate != null);
    addAll(children);
  }

  /// The delegate that controls the layout of the children.
  GridDelegate get delegate => _delegate;
  GridDelegate _delegate;
  void set delegate (GridDelegate newDelegate) {
    assert(newDelegate != null);
    if (_delegate == newDelegate)
      return;
    if (newDelegate.runtimeType != _delegate.runtimeType || newDelegate.shouldRelayout(_delegate)) {
      _specification = null;
      markNeedsLayout();
    }
    _delegate = newDelegate;
  }

  void set scrollDirection(Axis value) {
    assert(() {
      if (value != Axis.vertical)
        throw new RenderingError('RenderGrid doesn\'t yet support horizontal scrolling.');
      return true;
    });
    super.scrollDirection = value;
  }

  int get virtualChildCount => super.virtualChildCount ?? childCount;

  /// The virtual index of the first child.
  ///
  /// When asking the delegate for the position of each child, the grid will add
  /// the virtual child i to the indices of its children.
  int get virtualChildBase => _virtualChildBase;
  int _virtualChildBase;
  void set virtualChildBase(int value) {
    assert(value != null);
    if (_virtualChildBase == value)
      return;
    _virtualChildBase = value;
    markNeedsLayout();
  }

  void setupParentData(RenderBox child) {
    if (child.parentData is! GridParentData)
      child.parentData = new GridParentData();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return _delegate.getMinIntrinsicWidth(constraints, virtualChildCount);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return _delegate.getMaxIntrinsicWidth(constraints, virtualChildCount);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return _delegate.getMinIntrinsicHeight(constraints, virtualChildCount);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return _delegate.getMaxIntrinsicHeight(constraints, virtualChildCount);
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  GridSpecification get specification => _specification;
  GridSpecification _specification;
  int _specificationChildCount;
  BoxConstraints _specificationConstraints;

  void _updateGridSpecification() {
    if (_specification == null
        || _specificationChildCount != virtualChildCount
        || _specificationConstraints != constraints) {
      _specification = delegate.getGridSpecification(constraints, virtualChildCount);
      _specificationChildCount = virtualChildCount;
      _specificationConstraints = constraints;
    }
  }

  void performLayout() {
    _updateGridSpecification();
    final Size gridSize = _specification.gridSize;
    size = constraints.constrain(gridSize);

    if (callback != null)
      invokeLayoutCallback(callback);

    final double gridTopPadding = _specification.padding.top;
    final double gridLeftPadding = _specification.padding.left;
    int childIndex = virtualChildBase;
    RenderBox child = firstChild;
    while (child != null) {
      final GridParentData childParentData = child.parentData;

      GridChildPlacement placement = delegate.getChildPlacement(_specification, childIndex, childParentData.placementData);
      assert(placement.column >= 0);
      assert(placement.row >= 0);
      assert(placement.column + placement.columnSpan < _specification.columnOffsets.length);
      assert(placement.row + placement.rowSpan < _specification.rowOffsets.length);

      double tileLeft = _specification.columnOffsets[placement.column] + gridLeftPadding;
      double tileRight = _specification.columnOffsets[placement.column + placement.columnSpan] + gridLeftPadding;
      double tileTop = _specification.rowOffsets[placement.row] + gridTopPadding;
      double tileBottom = _specification.rowOffsets[placement.row + placement.rowSpan] + gridTopPadding;

      double childWidth = math.max(0.0, tileRight - tileLeft - _specification.columnSpacing);
      double childHeight = math.max(0.0, tileBottom - tileTop - _specification.rowSpacing);

      child.layout(new BoxConstraints(
        minWidth: childWidth,
        maxWidth: childWidth,
        minHeight: childHeight,
        maxHeight: childHeight
      ));

      childParentData.offset = new Offset(tileLeft, tileTop);
      childIndex += 1;

      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
  }
}
