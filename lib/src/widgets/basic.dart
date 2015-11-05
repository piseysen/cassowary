// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'framework.dart';

export 'dart:typed_data' show Uint8List;
export 'package:flutter/rendering.dart' show
    BackgroundImage,
    BlockDirection,
    Border,
    BorderSide,
    BoxConstraints,
    BoxDecoration,
    BoxDecorationPosition,
    BoxShadow,
    Canvas,
    Color,
    ColorFilter,
    EdgeDims,
    FlexAlignItems,
    FlexDirection,
    FlexJustifyContent,
    FontStyle,
    FontWeight,
    FractionalOffset,
    Gradient,
    HitTestBehavior,
    ImageFit,
    ImageRepeat,
    InputEvent,
    LinearGradient,
    Matrix4,
    Offset,
    OneChildLayoutDelegate,
    Paint,
    Path,
    PlainTextSpan,
    Point,
    PointerInputEvent,
    RadialGradient,
    Rect,
    ScrollDirection,
    Shape,
    ShrinkWrap,
    Size,
    StyledTextSpan,
    TextAlign,
    TextBaseline,
    TextDecoration,
    TextDecorationStyle,
    TextSpan,
    TextStyle,
    TransferMode,
    ValueChanged,
    VoidCallback,
    bold,
    normal,
    underline,
    overline,
    lineThrough;


// PAINTING NODES

class Opacity extends OneChildRenderObjectWidget {
  Opacity({ Key key, this.opacity, Widget child })
    : super(key: key, child: child) {
    assert(opacity >= 0.0 && opacity <= 1.0);
  }

  final double opacity;

  RenderOpacity createRenderObject() => new RenderOpacity(opacity: opacity);

  void updateRenderObject(RenderOpacity renderObject, Opacity oldWidget) {
    renderObject.opacity = opacity;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('opacity: $opacity');
  }
}

class ShaderMask extends OneChildRenderObjectWidget {
  ShaderMask({
    Key key,
    this.shaderCallback,
    this.transferMode: TransferMode.modulate,
    Widget child
  }) : super(key: key, child: child) {
    assert(shaderCallback != null);
    assert(transferMode != null);
  }

  final ShaderCallback shaderCallback;
  final TransferMode transferMode;

  RenderShaderMask createRenderObject() {
    return new RenderShaderMask(
      shaderCallback: shaderCallback,
      transferMode: transferMode
    );
  }

  void updateRenderObject(RenderShaderMask renderObject, ShaderMask oldWidget) {
    renderObject.shaderCallback = shaderCallback;
    renderObject.transferMode = transferMode;
  }
}

class DecoratedBox extends OneChildRenderObjectWidget {
  DecoratedBox({
    Key key,
    this.decoration,
    this.position: BoxDecorationPosition.background,
    Widget child
  }) : super(key: key, child: child) {
    assert(decoration != null);
    assert(position != null);
  }

  final BoxDecoration decoration;
  final BoxDecorationPosition position;

  RenderObject createRenderObject() => new RenderDecoratedBox(decoration: decoration, position: position);

  void updateRenderObject(RenderDecoratedBox renderObject, DecoratedBox oldWidget) {
    renderObject.decoration = decoration;
    renderObject.position = position;
  }
}

class CustomPaint extends OneChildRenderObjectWidget {
  CustomPaint({ Key key, this.onPaint, this.onHitTest, this.token, Widget child })
    : super(key: key, child: child) {
    assert(onPaint != null);
  }

  /// This widget repaints whenver you supply a new onPaint callback.
  ///
  /// If you use an anonymous closure for the onPaint callback, you'll trigger
  /// a repaint every time you build this widget, which might not be what you
  /// intend. Instead, consider passing a reference to a member function, which
  /// has a more stable identity.
  final CustomPaintCallback onPaint;

  final CustomHitTestCallback onHitTest;

  /// This widget repaints whenever you supply a new token.
  final Object token;

  RenderCustomPaint createRenderObject() => new RenderCustomPaint(onPaint: onPaint, onHitTest: onHitTest);

  void updateRenderObject(RenderCustomPaint renderObject, CustomPaint oldWidget) {
    if (oldWidget.token != token)
      renderObject.markNeedsPaint();
    renderObject.onPaint = onPaint;
    renderObject.onHitTest = onHitTest;
  }

  void didUnmountRenderObject(RenderCustomPaint renderObject) {
    renderObject.onPaint = null;
    renderObject.onHitTest = null;
  }
}

class ClipRect extends OneChildRenderObjectWidget {
  ClipRect({ Key key, Widget child }) : super(key: key, child: child);
  RenderClipRect createRenderObject() => new RenderClipRect();
}

class ClipRRect extends OneChildRenderObjectWidget {
  ClipRRect({ Key key, this.xRadius, this.yRadius, Widget child })
    : super(key: key, child: child);

  final double xRadius;
  final double yRadius;

  RenderClipRRect createRenderObject() => new RenderClipRRect(xRadius: xRadius, yRadius: yRadius);

  void updateRenderObject(RenderClipRRect renderObject, ClipRRect oldWidget) {
    renderObject.xRadius = xRadius;
    renderObject.yRadius = yRadius;
  }
}

class ClipOval extends OneChildRenderObjectWidget {
  ClipOval({ Key key, Widget child }) : super(key: key, child: child);
  RenderClipOval createRenderObject() => new RenderClipOval();
}


// POSITIONING AND SIZING NODES

class Transform extends OneChildRenderObjectWidget {
  Transform({ Key key, this.transform, this.origin, this.alignment, Widget child })
    : super(key: key, child: child) {
    assert(transform != null);
  }

  final Matrix4 transform;
  final Offset origin;
  final FractionalOffset alignment;

  RenderTransform createRenderObject() => new RenderTransform(transform: transform, origin: origin, alignment: alignment);

  void updateRenderObject(RenderTransform renderObject, Transform oldWidget) {
    renderObject.transform = transform;
    renderObject.origin = origin;
    renderObject.alignment = alignment;
  }
}

class Padding extends OneChildRenderObjectWidget {
  Padding({ Key key, this.padding, Widget child })
    : super(key: key, child: child) {
    assert(padding != null);
  }

  final EdgeDims padding;

  RenderPadding createRenderObject() => new RenderPadding(padding: padding);

  void updateRenderObject(RenderPadding renderObject, Padding oldWidget) {
    renderObject.padding = padding;
  }
}

class Align extends OneChildRenderObjectWidget {
  Align({
    Key key,
    this.alignment: const FractionalOffset(0.5, 0.5),
    this.shrinkWrap: ShrinkWrap.none,
    Widget child
  }) : super(key: key, child: child) {
    assert(shrinkWrap != null);
  }

  final FractionalOffset alignment;
  final ShrinkWrap shrinkWrap;

  RenderPositionedBox createRenderObject() => new RenderPositionedBox(alignment: alignment, shrinkWrap: shrinkWrap);

  void updateRenderObject(RenderPositionedBox renderObject, Align oldWidget) {
    renderObject.alignment = alignment;
    renderObject.shrinkWrap = shrinkWrap;
  }
}

class Center extends Align {
  Center({ Key key, ShrinkWrap shrinkWrap: ShrinkWrap.none, Widget child })
    : super(key: key, shrinkWrap: shrinkWrap, child: child);
}

class CustomOneChildLayout extends OneChildRenderObjectWidget {
  CustomOneChildLayout({
    Key key,
    this.delegate,
    this.token,
    Widget child
  }) : super(key: key, child: child) {
    assert(delegate != null);
  }

  /// A long-lived delegate that controls the layout of this widget.
  ///
  /// Whenever the delegate changes, we need to recompute the layout of this
  /// widget, which means you might not want to create a new delegate instance
  /// every time you build this widget. Instead, consider using a long-lived
  /// deletate (perhaps held in a component's state) that you re-use every time
  /// you build this widget.
  final OneChildLayoutDelegate delegate;
  final Object token;

  RenderCustomOneChildLayoutBox createRenderObject() => new RenderCustomOneChildLayoutBox(delegate: delegate);

  void updateRenderObject(RenderCustomOneChildLayoutBox renderObject, CustomOneChildLayout oldWidget) {
    if (oldWidget.token != token)
      renderObject.markNeedsLayout();
    renderObject.delegate = delegate;
  }
}

class LayoutId extends ParentDataWidget {
  LayoutId({
    Key key,
    Widget child,
    this.id
  }) : super(key: key, child: child);

  final Object id;

  void debugValidateAncestor(Widget ancestor) {
    assert(() {
      'LayoutId must placed inside a CustomMultiChildLayout';
      return ancestor is CustomMultiChildLayout;
    });
  }

  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is MultiChildLayoutParentData);
    final MultiChildLayoutParentData parentData = renderObject.parentData;
    if (parentData.id != id) {
      parentData.id = id;
      AbstractNode targetParent = renderObject.parent;
      if (targetParent is RenderObject)
        targetParent.markNeedsLayout();
    }
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('id: $id');
  }
}

class CustomMultiChildLayout extends MultiChildRenderObjectWidget {
  CustomMultiChildLayout(List<Widget> children, {
    Key key,
    this.delegate,
    this.token
  }) : super(key: key, children: children) {
    assert(delegate != null);
  }

  final MultiChildLayoutDelegate delegate;
  final Object token;

  RenderCustomMultiChildLayoutBox createRenderObject() {
    return new RenderCustomMultiChildLayoutBox(delegate: delegate);
  }

  void updateRenderObject(RenderCustomMultiChildLayoutBox renderObject, CustomMultiChildLayout oldWidget) {
    if (oldWidget.token != token)
      renderObject.markNeedsLayout();
    renderObject.delegate = delegate;
  }
}

class SizedBox extends OneChildRenderObjectWidget {
  SizedBox({ Key key, this.width, this.height, Widget child })
    : super(key: key, child: child);

  final double width;
  final double height;

  RenderConstrainedBox createRenderObject() => new RenderConstrainedBox(
    additionalConstraints: _additionalConstraints
  );

  BoxConstraints get _additionalConstraints {
    BoxConstraints result = const BoxConstraints();
    if (width != null)
      result = result.tightenWidth(width);
    if (height != null)
      result = result.tightenHeight(height);
    return result;
  }

  void updateRenderObject(RenderConstrainedBox renderObject, SizedBox oldWidget) {
    renderObject.additionalConstraints = _additionalConstraints;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (width != null)
      description.add('width: $width');
    if (height != null)
      description.add('height: $height');
  }
}

class ConstrainedBox extends OneChildRenderObjectWidget {
  ConstrainedBox({ Key key, this.constraints, Widget child })
    : super(key: key, child: child) {
    assert(constraints != null);
  }

  final BoxConstraints constraints;

  RenderConstrainedBox createRenderObject() => new RenderConstrainedBox(additionalConstraints: constraints);

  void updateRenderObject(RenderConstrainedBox renderObject, ConstrainedBox oldWidget) {
    renderObject.additionalConstraints = constraints;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$constraints');
  }
}

class FractionallySizedBox extends OneChildRenderObjectWidget {
  FractionallySizedBox({ Key key, this.width, this.height, Widget child })
    : super(key: key, child: child);

  final double width;
  final double height;

  RenderFractionallySizedBox createRenderObject() => new RenderFractionallySizedBox(
    widthFactor: width,
    heightFactor: height
  );

  void updateRenderObject(RenderFractionallySizedBox renderObject, FractionallySizedBox oldWidget) {
    renderObject.widthFactor = width;
    renderObject.heightFactor = height;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (width != null)
      description.add('width: $width');
    if (height != null)
      description.add('height: $height');
  }
}

class OverflowBox extends OneChildRenderObjectWidget {
  OverflowBox({ Key key, this.minWidth, this.maxWidth, this.minHeight, this.maxHeight, Widget child })
    : super(key: key, child: child);

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;

  RenderOverflowBox createRenderObject() => new RenderOverflowBox(
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight
  );

  void updateRenderObject(RenderOverflowBox renderObject, OverflowBox oldWidget) {
    renderObject.minWidth = minWidth;
    renderObject.maxWidth = maxWidth;
    renderObject.minHeight = minHeight;
    renderObject.maxHeight = maxHeight;
  }
}

class SizedOverflowBox extends OneChildRenderObjectWidget {
  SizedOverflowBox({ Key key, this.size, Widget child })
    : super(key: key, child: child);

  final Size size;

  RenderSizedOverflowBox createRenderObject() => new RenderSizedOverflowBox(requestedSize: size);

  void updateRenderObject(RenderSizedOverflowBox renderObject, SizedOverflowBox oldWidget) {
    renderObject.requestedSize = size;
  }
}

class OffStage extends OneChildRenderObjectWidget {
  OffStage({ Key key, Widget child })
    : super(key: key, child: child);

  RenderOffStage createRenderObject() => new RenderOffStage();
}

class AspectRatio extends OneChildRenderObjectWidget {
  AspectRatio({ Key key, this.aspectRatio, Widget child })
    : super(key: key, child: child) {
    assert(aspectRatio != null);
  }

  final double aspectRatio;

  RenderAspectRatio createRenderObject() => new RenderAspectRatio(aspectRatio: aspectRatio);

  void updateRenderObject(RenderAspectRatio renderObject, AspectRatio oldWidget) {
    renderObject.aspectRatio = aspectRatio;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('aspectRatio: $aspectRatio');
  }
}

class IntrinsicWidth extends OneChildRenderObjectWidget {
  IntrinsicWidth({ Key key, this.stepWidth, this.stepHeight, Widget child })
    : super(key: key, child: child);

  final double stepWidth;
  final double stepHeight;

  RenderIntrinsicWidth createRenderObject() => new RenderIntrinsicWidth(stepWidth: stepWidth, stepHeight: stepHeight);

  void updateRenderObject(RenderIntrinsicWidth renderObject, IntrinsicWidth oldWidget) {
    renderObject.stepWidth = stepWidth;
    renderObject.stepHeight = stepHeight;
  }
}

class IntrinsicHeight extends OneChildRenderObjectWidget {
  IntrinsicHeight({ Key key, Widget child }) : super(key: key, child: child);
  RenderIntrinsicHeight createRenderObject() => new RenderIntrinsicHeight();
}

class Baseline extends OneChildRenderObjectWidget {
  Baseline({ Key key, this.baseline, this.baselineType: TextBaseline.alphabetic, Widget child })
    : super(key: key, child: child) {
    assert(baseline != null);
    assert(baselineType != null);
  }

  final double baseline; // in pixels
  final TextBaseline baselineType;

  RenderBaseline createRenderObject() => new RenderBaseline(baseline: baseline, baselineType: baselineType);

  void updateRenderObject(RenderBaseline renderObject, Baseline oldWidget) {
    renderObject.baseline = baseline;
    renderObject.baselineType = baselineType;
  }
}

class Viewport extends OneChildRenderObjectWidget {
  Viewport({
    Key key,
    this.scrollDirection: ScrollDirection.vertical,
    this.scrollOffset: Offset.zero,
    Widget child
  }) : super(key: key, child: child) {
    assert(scrollDirection != null);
    assert(scrollOffset != null);
  }

  final ScrollDirection scrollDirection;
  final Offset scrollOffset;

  RenderViewport createRenderObject() => new RenderViewport(scrollDirection: scrollDirection, scrollOffset: scrollOffset);

  void updateRenderObject(RenderViewport renderObject, Viewport oldWidget) {
    // Order dependency: RenderViewport validates scrollOffset based on scrollDirection.
    renderObject.scrollDirection = scrollDirection;
    renderObject.scrollOffset = scrollOffset;
  }
}

class SizeObserver extends OneChildRenderObjectWidget {
  SizeObserver({ Key key, this.onSizeChanged, Widget child })
    : super(key: key, child: child) {
    assert(onSizeChanged != null);
  }

  final SizeChangedCallback onSizeChanged;

  RenderSizeObserver createRenderObject() => new RenderSizeObserver(onSizeChanged: onSizeChanged);

  void updateRenderObject(RenderSizeObserver renderObject, SizeObserver oldWidget) {
    renderObject.onSizeChanged = onSizeChanged;
  }

  void didUnmountRenderObject(RenderSizeObserver renderObject) {
    renderObject.onSizeChanged = null;
  }
}


// CONVENIENCE CLASS TO COMBINE COMMON PAINTING, POSITIONING, AND SIZING NODES

class Container extends StatelessComponent {

  Container({
    Key key,
    this.child,
    this.constraints,
    this.decoration,
    this.foregroundDecoration,
    this.margin,
    this.padding,
    this.transform,
    this.width,
    this.height
  }) : super(key: key) {
    assert(margin == null || margin.isNonNegative);
    assert(padding == null || padding.isNonNegative);
  }

  final Widget child;
  final BoxConstraints constraints;
  final BoxDecoration decoration;
  final BoxDecoration foregroundDecoration;
  final EdgeDims margin;
  final EdgeDims padding;
  final Matrix4 transform;
  final double width;
  final double height;

  EdgeDims get _paddingIncludingBorder {
    if (decoration == null || decoration.border == null)
      return padding;
    EdgeDims borderPadding = decoration.border.dimensions;
    if (padding == null)
      return borderPadding;
    return padding + borderPadding;
  }

  Widget build(BuildContext context) {
    Widget current = child;

    if (child == null && (width == null || height == null))
      current = new ConstrainedBox(constraints: const BoxConstraints.expand());

    EdgeDims effectivePadding = _paddingIncludingBorder;
    if (effectivePadding != null)
      current = new Padding(padding: effectivePadding, child: current);

    if (decoration != null)
      current = new DecoratedBox(decoration: decoration, child: current);

    if (foregroundDecoration != null) {
      current = new DecoratedBox(
        decoration: foregroundDecoration,
        position: BoxDecorationPosition.foreground,
        child: current
      );
    }

    if (width != null || height != null) {
      current = new SizedBox(
        width: width,
        height: height,
        child: current
      );
    }

    if (constraints != null)
      current = new ConstrainedBox(constraints: constraints, child: current);

    if (margin != null)
      current = new Padding(padding: margin, child: current);

    if (transform != null)
      current = new Transform(transform: transform, child: current);

    return current;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (constraints != null)
      description.add('$constraints');
    if (decoration != null)
      description.add('has background');
    if (foregroundDecoration != null)
      description.add('has foreground');
    if (margin != null)
      description.add('margin: $margin');
    if (padding != null)
      description.add('padding: $padding');
    if (transform != null)
      description.add('has transform');
    if (width != null)
      description.add('width: $width');
    if (height != null)
      description.add('height: $height');
  }

}


// LAYOUT NODES

class BlockBody extends MultiChildRenderObjectWidget {
  BlockBody(List<Widget> children, {
    Key key,
    this.direction: BlockDirection.vertical
  }) : super(key: key, children: children) {
    assert(direction != null);
  }

  final BlockDirection direction;

  RenderBlock createRenderObject() => new RenderBlock(direction: direction);

  void updateRenderObject(RenderBlock renderObject, BlockBody oldWidget) {
    renderObject.direction = direction;
  }
}

class Stack extends MultiChildRenderObjectWidget {
  Stack(List<Widget> children, {
    Key key,
    this.alignment: const FractionalOffset(0.0, 0.0)
  }) : super(key: key, children: children);

  final FractionalOffset alignment;

  RenderStack createRenderObject() => new RenderStack(alignment: alignment);

  void updateRenderObject(RenderStack renderObject, Stack oldWidget) {
    renderObject.alignment = alignment;
  }
}

class IndexedStack extends MultiChildRenderObjectWidget {
  IndexedStack(List<Widget> children, {
    Key key,
    this.alignment: const FractionalOffset(0.0, 0.0),
    this.index: 0
  }) : super(key: key, children: children);

  final int index;
  final FractionalOffset alignment;

  RenderIndexedStack createRenderObject() => new RenderIndexedStack(index: index, alignment: alignment);

  void updateRenderObject(RenderIndexedStack renderObject, IndexedStack oldWidget) {
    super.updateRenderObject(renderObject, oldWidget);
    renderObject.index = index;
    renderObject.alignment = alignment;
  }
}

class Positioned extends ParentDataWidget {
  Positioned({
    Key key,
    Widget child,
    this.top,
    this.right,
    this.bottom,
    this.left
  }) : super(key: key, child: child);

  final double top;
  final double right;
  final double bottom;
  final double left;

  void debugValidateAncestor(Widget ancestor) {
    assert(() {
      'Positioned must placed inside a Stack';
      return ancestor is Stack;
    });
  }

  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is StackParentData);
    final StackParentData parentData = renderObject.parentData;
    bool needsLayout = false;

    if (parentData.top != top) {
      parentData.top = top;
      needsLayout = true;
    }

    if (parentData.right != right) {
      parentData.right = right;
      needsLayout = true;
    }

    if (parentData.bottom != bottom) {
      parentData.bottom = bottom;
      needsLayout = true;
    }

    if (parentData.left != left) {
      parentData.left = left;
      needsLayout = true;
    }

    if (needsLayout) {
      AbstractNode targetParent = renderObject.parent;
      if (targetParent is RenderObject)
        targetParent.markNeedsLayout();
    }
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (left != null)
      description.add('left: $left');
    if (top != null)
      description.add('top: $top');
    if (right != null)
      description.add('right: $right');
    if (bottom != null)
      description.add('bottom: $bottom');
  }
}

class Grid extends MultiChildRenderObjectWidget {
  Grid(List<Widget> children, { Key key, this.maxChildExtent })
    : super(key: key, children: children) {
    assert(maxChildExtent != null);
  }

  final double maxChildExtent;

  RenderGrid createRenderObject() => new RenderGrid(maxChildExtent: maxChildExtent);

  void updateRenderObject(RenderGrid renderObject, Grid oldWidget) {
    renderObject.maxChildExtent = maxChildExtent;
  }
}

class Flex extends MultiChildRenderObjectWidget {
  Flex(List<Widget> children, {
    Key key,
    this.direction: FlexDirection.horizontal,
    this.justifyContent: FlexJustifyContent.start,
    this.alignItems: FlexAlignItems.center,
    this.textBaseline
  }) : super(key: key, children: children) {
    assert(direction != null);
    assert(justifyContent != null);
    assert(alignItems != null);
  }

  final FlexDirection direction;
  final FlexJustifyContent justifyContent;
  final FlexAlignItems alignItems;
  final TextBaseline textBaseline;

  RenderFlex createRenderObject() => new RenderFlex(direction: direction, justifyContent: justifyContent, alignItems: alignItems, textBaseline: textBaseline);

  void updateRenderObject(RenderFlex renderObject, Flex oldWidget) {
    renderObject.direction = direction;
    renderObject.justifyContent = justifyContent;
    renderObject.alignItems = alignItems;
    renderObject.textBaseline = textBaseline;
  }
}

class Row extends Flex {
  Row(List<Widget> children, {
    Key key,
    justifyContent: FlexJustifyContent.start,
    alignItems: FlexAlignItems.center,
    textBaseline
  }) : super(children, key: key, direction: FlexDirection.horizontal, justifyContent: justifyContent, alignItems: alignItems, textBaseline: textBaseline);
}

class Column extends Flex {
  Column(List<Widget> children, {
    Key key,
    justifyContent: FlexJustifyContent.start,
    alignItems: FlexAlignItems.center,
    textBaseline
  }) : super(children, key: key, direction: FlexDirection.vertical, justifyContent: justifyContent, alignItems: alignItems, textBaseline: textBaseline);
}

class Flexible extends ParentDataWidget {
  Flexible({ Key key, this.flex: 1, Widget child })
    : super(key: key, child: child);

  final int flex;

  void debugValidateAncestor(Widget ancestor) {
    assert(() {
      'Flexible must placed inside a Flex';
      return ancestor is Flex;
    });
  }

  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is FlexParentData);
    final FlexParentData parentData = renderObject.parentData;
    if (parentData.flex != flex) {
      parentData.flex = flex;
      AbstractNode targetParent = renderObject.parent;
      if (targetParent is RenderObject)
        targetParent.markNeedsLayout();
    }
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('flex: $flex');
  }
}

class Paragraph extends LeafRenderObjectWidget {
  Paragraph({ Key key, this.text }) : super(key: key) {
    assert(text != null);
  }

  final TextSpan text;

  RenderParagraph createRenderObject() => new RenderParagraph(text);

  void updateRenderObject(RenderParagraph renderObject, Paragraph oldWidget) {
    renderObject.text = text;
  }
}

class StyledText extends StatelessComponent {
  // elements ::= "string" | [<text-style> <elements>*]
  // Where "string" is text to display and text-style is an instance of
  // TextStyle. The text-style applies to all of the elements that follow.
  StyledText({ this.elements, Key key }) : super(key: key) {
    assert(_toSpan(elements) != null);
  }

  final dynamic elements;

  TextSpan _toSpan(dynamic element) {
    if (element is String)
      return new PlainTextSpan(element);
    if (element is Iterable) {
      dynamic first = element.first;
      if (first is! TextStyle)
        throw new ArgumentError("First element of Iterable is a ${first.runtimeType} not a TextStyle");
      return new StyledTextSpan(first, element.skip(1).map(_toSpan).toList());
    }
    throw new ArgumentError("Element is ${element.runtimeType} not a String or an Iterable");
  }

  Widget build(BuildContext context) {
    return new Paragraph(text: _toSpan(elements));
  }
}

class DefaultTextStyle extends InheritedWidget {
  DefaultTextStyle({
    Key key,
    this.style,
    Widget child
  }) : super(key: key, child: child) {
    assert(style != null);
    assert(child != null);
  }

  final TextStyle style;

  static TextStyle of(BuildContext context) {
    DefaultTextStyle result = context.inheritedWidgetOfType(DefaultTextStyle);
    return result?.style;
  }

  bool updateShouldNotify(DefaultTextStyle old) => style != old.style;

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    '$style'.split('\n').forEach(description.add);
  }
}

class Text extends StatelessComponent {
  Text(this.data, { Key key, this.style }) : super(key: key) {
    assert(data != null);
  }

  final String data;
  final TextStyle style;

  Widget build(BuildContext context) {
    TextSpan text = new PlainTextSpan(data);
    TextStyle combinedStyle;
    if (style == null || style.inherit) {
      combinedStyle = DefaultTextStyle.of(context)?.merge(style) ?? style;
    } else {
      combinedStyle = style;
    }
    if (combinedStyle != null)
      text = new StyledTextSpan(combinedStyle, <TextSpan>[text]);
    return new Paragraph(text: text);
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('"$data"');
    if (style != null)
      '$style'.split('\n').forEach(description.add);
  }
}

class Image extends LeafRenderObjectWidget {
  Image({
    Key key,
    this.image,
    this.width,
    this.height,
    this.colorFilter,
    this.fit,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice
  }) : super(key: key);

  final ui.Image image;
  final double width;
  final double height;
  final ColorFilter colorFilter;
  final ImageFit fit;
  final ImageRepeat repeat;
  final Rect centerSlice;

  RenderImage createRenderObject() => new RenderImage(
    image: image,
    width: width,
    height: height,
    colorFilter: colorFilter,
    fit: fit,
    repeat: repeat,
    centerSlice: centerSlice);

  void updateRenderObject(RenderImage renderObject, Image oldWidget) {
    renderObject.image = image;
    renderObject.width = width;
    renderObject.height = height;
    renderObject.colorFilter = colorFilter;
    renderObject.fit = fit;
    renderObject.repeat = repeat;
    renderObject.centerSlice = centerSlice;
  }
}

class ImageListener extends StatefulComponent {
  ImageListener({
    Key key,
    this.image,
    this.width,
    this.height,
    this.colorFilter,
    this.fit,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice
  }) : super(key: key) {
    assert(image != null);
  }

  final ImageResource image;
  final double width;
  final double height;
  final ColorFilter colorFilter;
  final ImageFit fit;
  final ImageRepeat repeat;
  final Rect centerSlice;

  _ImageListenerState createState() => new _ImageListenerState();
}

class _ImageListenerState extends State<ImageListener> {
  void initState() {
    super.initState();
    config.image.addListener(_handleImageChanged);
  }

  ui.Image _resolvedImage;

  void _handleImageChanged(ui.Image resolvedImage) {
    setState(() {
      _resolvedImage = resolvedImage;
    });
  }

  void dispose() {
    config.image.removeListener(_handleImageChanged);
    super.dispose();
  }

  void didUpdateConfig(ImageListener oldConfig) {
    if (config.image != oldConfig.image) {
      oldConfig.image.removeListener(_handleImageChanged);
      config.image.addListener(_handleImageChanged);
    }
  }

  Widget build(BuildContext context) {
    return new Image(
      image: _resolvedImage,
      width: config.width,
      height: config.height,
      colorFilter: config.colorFilter,
      fit: config.fit,
      repeat: config.repeat,
      centerSlice: config.centerSlice
    );
  }
}

class NetworkImage extends StatelessComponent {
  NetworkImage({
    Key key,
    this.src,
    this.width,
    this.height,
    this.colorFilter,
    this.fit,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice
  }) : super(key: key);

  final String src;
  final double width;
  final double height;
  final ColorFilter colorFilter;
  final ImageFit fit;
  final ImageRepeat repeat;
  final Rect centerSlice;

  Widget build(BuildContext context) {
    return new ImageListener(
      image: imageCache.load(src),
      width: width,
      height: height,
      colorFilter: colorFilter,
      fit: fit,
      repeat: repeat,
      centerSlice: centerSlice
    );
  }
}

class DefaultAssetBundle extends InheritedWidget {
  DefaultAssetBundle({
    Key key,
    this.bundle,
    Widget child
  }) : super(key: key, child: child) {
    assert(bundle != null);
    assert(child != null);
  }

  final AssetBundle bundle;

  static AssetBundle of(BuildContext context) {
    DefaultAssetBundle result = context.inheritedWidgetOfType(DefaultAssetBundle);
    return result?.bundle;
  }

  bool updateShouldNotify(DefaultAssetBundle old) => bundle != old.bundle;
}

class RawImage extends StatelessComponent {
  RawImage({
    Key key,
    this.bytes,
    this.width,
    this.height,
    this.colorFilter,
    this.fit,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice
  }) : super(key: key);

  final Uint8List bytes;
  final double width;
  final double height;
  final ColorFilter colorFilter;
  final ImageFit fit;
  final ImageRepeat repeat;
  final Rect centerSlice;

  Widget build(BuildContext context) {
    ImageResource image = new ImageResource(decodeImageFromList(bytes));
    return new ImageListener(
      image: image,
      width: width,
      height: height,
      colorFilter: colorFilter,
      fit: fit,
      repeat: repeat,
      centerSlice: centerSlice
    );
  }
}

class AssetImage extends StatelessComponent {
  AssetImage({
    Key key,
    this.name,
    this.bundle,
    this.width,
    this.height,
    this.colorFilter,
    this.fit,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice
  }) : super(key: key);

  final String name;
  final AssetBundle bundle;
  final double width;
  final double height;
  final ColorFilter colorFilter;
  final ImageFit fit;
  final ImageRepeat repeat;
  final Rect centerSlice;

  Widget build(BuildContext context) {
    return new ImageListener(
      image: (bundle ?? DefaultAssetBundle.of(context)).loadImage(name),
      width: width,
      height: height,
      colorFilter: colorFilter,
      fit: fit,
      repeat: repeat,
      centerSlice: centerSlice
    );
  }
}

class WidgetToRenderBoxAdapter extends LeafRenderObjectWidget {
  WidgetToRenderBoxAdapter(RenderBox renderBox)
    : renderBox = renderBox,
      // WidgetToRenderBoxAdapter objects are keyed to their render box. This
      // prevents the widget being used in the widget hierarchy in two different
      // places, which would cause the RenderBox to get inserted in multiple
      // places in the RenderObject tree.
      super(key: new GlobalObjectKey(renderBox)) {
    assert(renderBox != null);
  }

  final RenderBox renderBox;

  RenderBox createRenderObject() => renderBox;
}


// EVENT HANDLING

class Listener extends OneChildRenderObjectWidget {
  Listener({
    Key key,
    Widget child,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    this.behavior: HitTestBehavior.deferToChild
  }) : super(key: key, child: child) {
    assert(behavior != null);
  }

  final PointerEventListener onPointerDown;
  final PointerEventListener onPointerMove;
  final PointerEventListener onPointerUp;
  final PointerEventListener onPointerCancel;
  final HitTestBehavior behavior;

  RenderPointerListener createRenderObject() => new RenderPointerListener(
    onPointerDown: onPointerDown,
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onPointerCancel: onPointerCancel,
    behavior: behavior
  );

  void updateRenderObject(RenderPointerListener renderObject, Listener oldWidget) {
    renderObject.onPointerDown = onPointerDown;
    renderObject.onPointerMove = onPointerMove;
    renderObject.onPointerUp = onPointerUp;
    renderObject.onPointerCancel = onPointerCancel;
    renderObject.behavior = behavior;
  }
}

class IgnorePointer extends OneChildRenderObjectWidget {
  IgnorePointer({ Key key, Widget child, this.ignoring: true })
    : super(key: key, child: child);

  final bool ignoring;

  RenderIgnorePointer createRenderObject() => new RenderIgnorePointer(ignoring: ignoring);

  void updateRenderObject(RenderIgnorePointer renderObject, IgnorePointer oldWidget) {
    renderObject.ignoring = ignoring;
  }
}


// UTILITY NODES

class MetaData extends OneChildRenderObjectWidget {
  MetaData({ Key key, Widget child, this.metaData })
    : super(key: key, child: child);

  final dynamic metaData;

  RenderMetaData createRenderObject() => new RenderMetaData(metaData: metaData);

  void updateRenderObject(RenderMetaData renderObject, MetaData oldWidget) {
    renderObject.metaData = metaData;
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$metaData');
  }
}

class KeyedSubtree extends StatelessComponent {
  KeyedSubtree({ Key key, this.child })
    : super(key: key);

  final Widget child;

  Widget build(BuildContext context) => child;
}
