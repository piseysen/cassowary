// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'box.dart';
import 'object.dart';

class MultiChildLayoutParentData extends ContainerBoxParentDataMixin<RenderBox> {
  Object id;
}

abstract class MultiChildLayoutDelegate {
  final Map<Object, RenderBox> _idToChild = new Map<Object, RenderBox>();

  /// Returns the size of this object given the incomming constraints.
  /// The size cannot reflect the instrinsic sizes of the children.
  /// If this layout has a fixed width or height the returned size
  /// can reflect that.
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  /// True if a non-null LayoutChild was provided for the specified id.
  bool isChild(Object childId) => _idToChild[childId] != null;

  /// Ask the child to update its layout within the limits specified by
  /// the constraints parameter. The child's size is returned.
  Size layoutChild(Object childId, BoxConstraints constraints) {
    final RenderBox child = _idToChild[childId];
    assert(child != null);
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  /// Specify the child's origin relative to this origin.
  void positionChild(Object childId, Point position) {
    final RenderBox child = _idToChild[childId];
    assert(child != null);
    final MultiChildLayoutParentData childParentData = child.parentData;
    childParentData.position = position;
  }

  void _callPerformLayout(Size size, BoxConstraints constraints, RenderBox firstChild) {
    RenderBox child = firstChild;
    while (child != null) {
      final MultiChildLayoutParentData childParentData = child.parentData;
      assert(childParentData.id != null);
      _idToChild[childParentData.id] = child;
      child = childParentData.nextSibling;
    }
    performLayout(size, constraints);
    _idToChild.clear();
  }

  /// Layout and position all children given this widget's size and the specified
  /// constraints. This method must apply layoutChild() to each child. It should
  /// specify the final position of each child with positionChild().
  void performLayout(Size size, BoxConstraints constraints);
}

class RenderCustomMultiChildLayoutBox extends RenderBox
  with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
       RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderCustomMultiChildLayoutBox({
    List<RenderBox> children,
    MultiChildLayoutDelegate delegate
  }) : _delegate = delegate {
    assert(delegate != null);
    addAll(children);
  }

  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData)
      child.parentData = new MultiChildLayoutParentData();
  }

  MultiChildLayoutDelegate get delegate => _delegate;
  MultiChildLayoutDelegate _delegate;
  void set delegate (MultiChildLayoutDelegate newDelegate) {
    assert(newDelegate != null);
    if (_delegate == newDelegate)
      return;
    _delegate = newDelegate;
    markNeedsLayout();
  }

  Size _getSize(BoxConstraints constraints) {
    return constraints.constrain(_delegate.getSize(constraints));
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  bool get sizedByParent => true;

  void performResize() {
    size = _getSize(constraints);
  }

  void performLayout() {
    delegate._callPerformLayout(size, constraints, firstChild);
  }

  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  bool hitTestChildren(HitTestResult result, { Point position }) {
    return defaultHitTestChildren(result, position: position);
  }
}
