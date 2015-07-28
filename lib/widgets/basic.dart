// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:sky' as sky;

import 'package:vector_math/vector_math.dart';

import 'package:sky/mojo/asset_bundle.dart';
import 'package:sky/mojo/net/image_cache.dart' as image_cache;
import 'package:sky/painting/text_style.dart';
import 'package:sky/rendering/block.dart';
import 'package:sky/rendering/box.dart';
import 'package:sky/rendering/flex.dart';
import 'package:sky/rendering/object.dart';
import 'package:sky/rendering/paragraph.dart';
import 'package:sky/rendering/stack.dart';
import 'package:sky/widgets/default_text_style.dart';
import 'package:sky/widgets/widget.dart';

export 'package:sky/rendering/box.dart' show BackgroundImage, BoxConstraints, BoxDecoration, Border, BorderSide, EdgeDims;
export 'package:sky/rendering/flex.dart' show FlexDirection, FlexJustifyContent, FlexAlignItems;
export 'package:sky/rendering/object.dart' show Point, Offset, Size, Rect, Color, Paint, Path;
export 'package:sky/widgets/widget.dart' show Key, GlobalKey, Widget, Component, StatefulComponent, App, runApp, Listener, ParentDataNode;


// PAINTING NODES

class Opacity extends OneChildRenderObjectWrapper {
  Opacity({ Key key, this.opacity, Widget child })
    : super(key: key, child: child);

  final double opacity;

  RenderOpacity createNode() => new RenderOpacity(opacity: opacity);
  RenderOpacity get root => super.root;

  void syncRenderObject(Opacity old) {
    super.syncRenderObject(old);
    root.opacity = opacity;
  }
}

class ColorFilter extends OneChildRenderObjectWrapper {
  ColorFilter({ Key key, this.color, this.transferMode, Widget child })
    : super(key: key, child: child);

  final Color color;
  final sky.TransferMode transferMode;

  RenderColorFilter createNode() => new RenderColorFilter(color: color, transferMode: transferMode);
  RenderColorFilter get root => super.root;

  void syncRenderObject(ColorFilter old) {
    super.syncRenderObject(old);
    root.color = color;
    root.transferMode = transferMode;
  }
}

class DecoratedBox extends OneChildRenderObjectWrapper {
  DecoratedBox({ Key key, this.decoration, Widget child })
    : super(key: key, child: child);

  final BoxDecoration decoration;

  RenderDecoratedBox createNode() => new RenderDecoratedBox(decoration: decoration);
  RenderDecoratedBox get root => super.root;

  void syncRenderObject(DecoratedBox old) {
    super.syncRenderObject(old);
    root.decoration = decoration;
  }
}

class CustomPaint extends OneChildRenderObjectWrapper {
  CustomPaint({ Key key, this.callback, this.token, Widget child })
    : super(key: key, child: child);

  final CustomPaintCallback callback;
  final dynamic token; // set this to be repainted automatically when the token changes

  RenderCustomPaint createNode() => new RenderCustomPaint(callback: callback);
  RenderCustomPaint get root => super.root;

  void syncRenderObject(CustomPaint old) {
    super.syncRenderObject(old);
    if (old != null && old.token != token)
      root.markNeedsPaint();
    root.callback = callback;
  }

  void remove() {
    root.callback = null;
    super.remove();
  }
}

class ClipRect extends OneChildRenderObjectWrapper {
  ClipRect({ Key key, Widget child })
    : super(key: key, child: child);

  RenderClipRect createNode() => new RenderClipRect();
  RenderClipRect get root => super.root;

  // Nothing to sync, so we don't implement syncRenderObject()
}

class ClipRRect extends OneChildRenderObjectWrapper {
  ClipRRect({ Key key, this.xRadius, this.yRadius, Widget child })
    : super(key: key, child: child);

  final double xRadius;
  final double yRadius;

  RenderClipRRect createNode() => new RenderClipRRect(xRadius: xRadius, yRadius: yRadius);
  RenderClipRRect get root => super.root;

  void syncRenderObject(ClipRRect old) {
    super.syncRenderObject(old);
    root.xRadius = xRadius;
    root.yRadius = yRadius;
  }
}

class ClipOval extends OneChildRenderObjectWrapper {
  ClipOval({ Key key, Widget child })
    : super(key: key, child: child);

  RenderClipOval createNode() => new RenderClipOval();
  RenderClipOval get root => super.root;

  // Nothing to sync, so we don't implement syncRenderObject()
}


// POSITIONING AND SIZING NODES

class Transform extends OneChildRenderObjectWrapper {
  Transform({ Key key, this.transform, Widget child })
    : super(key: key, child: child);

  final Matrix4 transform;

  RenderTransform createNode() => new RenderTransform(transform: transform);
  RenderTransform get root => super.root;

  void syncRenderObject(Transform old) {
    super.syncRenderObject(old);
    root.transform = transform;
  }
}

class Padding extends OneChildRenderObjectWrapper {
  Padding({ Key key, this.padding, Widget child })
    : super(key: key, child: child);

  final EdgeDims padding;

  RenderPadding createNode() => new RenderPadding(padding: padding);
  RenderPadding get root => super.root;

  void syncRenderObject(Padding old) {
    super.syncRenderObject(old);
    root.padding = padding;
  }
}

class Center extends OneChildRenderObjectWrapper {
  Center({ Key key, Widget child })
    : super(key: key, child: child);

  RenderPositionedBox createNode() => new RenderPositionedBox();
  RenderPositionedBox get root => super.root;

  // Nothing to sync, so we don't implement syncRenderObject()
}

class SizedBox extends OneChildRenderObjectWrapper {
  SizedBox({ Key key, this.width, this.height, Widget child })
    : super(key: key, child: child);

  final double width;
  final double height;

  RenderConstrainedBox createNode() => new RenderConstrainedBox(additionalConstraints: _additionalConstraints());
  RenderConstrainedBox get root => super.root;

  BoxConstraints _additionalConstraints() {
    BoxConstraints result = const BoxConstraints();
    if (width != null)
      result = result.applyWidth(width);
    if (height != null)
      result = result.applyHeight(height);
    return result;
  }

  void syncRenderObject(SizedBox old) {
    super.syncRenderObject(old);
    root.additionalConstraints = _additionalConstraints();
  }
}

class ConstrainedBox extends OneChildRenderObjectWrapper {
  ConstrainedBox({ Key key, this.constraints, Widget child })
    : super(key: key, child: child);

  final BoxConstraints constraints;

  RenderConstrainedBox createNode() => new RenderConstrainedBox(additionalConstraints: constraints);
  RenderConstrainedBox get root => super.root;

  void syncRenderObject(ConstrainedBox old) {
    super.syncRenderObject(old);
    root.additionalConstraints = constraints;
  }
}

class AspectRatio extends OneChildRenderObjectWrapper {
  AspectRatio({ Key key, this.aspectRatio, Widget child })
    : super(key: key, child: child);

  final double aspectRatio;

  RenderAspectRatio createNode() => new RenderAspectRatio(aspectRatio: aspectRatio);
  RenderAspectRatio get root => super.root;

  void syncRenderObject(AspectRatio old) {
    super.syncRenderObject(old);
    root.aspectRatio = aspectRatio;
  }
}

class ShrinkWrapWidth extends OneChildRenderObjectWrapper {
  ShrinkWrapWidth({ Key key, this.stepWidth, this.stepHeight, Widget child })
    : super(key: key, child: child);

  final double stepWidth;
  final double stepHeight;

  RenderShrinkWrapWidth createNode() => new RenderShrinkWrapWidth();
  RenderShrinkWrapWidth get root => super.root;

  void syncRenderObject(ShrinkWrapWidth old) {
    super.syncRenderObject(old);
    root.stepWidth = stepWidth;
    root.stepHeight = stepHeight;
  }
}

class Baseline extends OneChildRenderObjectWrapper {
  Baseline({ Key key, this.baseline, this.baselineType: TextBaseline.alphabetic, Widget child })
    : super(key: key, child: child);

  final double baseline; // in pixels
  final TextBaseline baselineType;

  RenderBaseline createNode() => new RenderBaseline(baseline: baseline, baselineType: baselineType);
  RenderBaseline get root => super.root;

  void syncRenderObject(Baseline old) {
    super.syncRenderObject(old);
    root.baseline = baseline;
    root.baselineType = baselineType;
  }
}

class Viewport extends OneChildRenderObjectWrapper {
  Viewport({ Key key, this.offset: 0.0, Widget child })
    : super(key: key, child: child);

  final double offset;

  RenderViewport createNode() => new RenderViewport(scrollOffset: new Offset(0.0, offset));
  RenderViewport get root => super.root;

  void syncRenderObject(Viewport old) {
    super.syncRenderObject(old);
    root.scrollOffset = new Offset(0.0, offset);
  }
}

class SizeObserver extends OneChildRenderObjectWrapper {
  SizeObserver({ Key key, this.callback, Widget child })
    : super(key: key, child: child);

  final SizeChangedCallback callback;

  RenderSizeObserver createNode() => new RenderSizeObserver(callback: callback);
  RenderSizeObserver get root => super.root;

  void syncRenderObject(SizeObserver old) {
    super.syncRenderObject(old);
    root.callback = callback;
  }

  void remove() {
    root.callback = null;
    super.remove();
  }
}


// CONVENIENCE CLASS TO COMBINE COMMON PAINTING, POSITIONING, AND SIZING NODES

class Container extends Component {

  Container({
    Key key,
    this.child,
    this.constraints,
    this.decoration,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.transform
  }) : super(key: key);

  final Widget child;
  final BoxConstraints constraints;
  final BoxDecoration decoration;
  final EdgeDims margin;
  final EdgeDims padding;
  final Matrix4 transform;
  final double width;
  final double height;

  Widget build() {
    Widget current = child;

    if (child == null && width == null && height == null)
      current = new ConstrainedBox(constraints: BoxConstraints.expand);

    if (padding != null)
      current = new Padding(padding: padding, child: current);

    if (decoration != null)
      current = new DecoratedBox(decoration: decoration, child: current);

    if (width != null || height != null)
      current = new SizedBox(
        width: width,
        height: height,
        child: current
      );

    if (constraints != null)
      current = new ConstrainedBox(constraints: constraints, child: current);

    if (margin != null)
      current = new Padding(padding: margin, child: current);

    if (transform != null)
      current = new Transform(transform: transform, child: current);

    return current;
  }

}


// LAYOUT NODES

class Block extends MultiChildRenderObjectWrapper {
  Block(List<Widget> children, { Key key })
    : super(key: key, children: children);

  RenderBlock createNode() => new RenderBlock();
  RenderBlock get root => super.root;
}

class Stack extends MultiChildRenderObjectWrapper {
  Stack(List<Widget> children, { Key key })
    : super(key: key, children: children);

  RenderStack createNode() => new RenderStack();
  RenderStack get root => super.root;
}

class Positioned extends ParentDataNode {
  Positioned({
    Key key,
    Widget child,
    double top,
    double right,
    double bottom,
    double left
  }) : super(child,
             new StackParentData()..top = top
                                  ..right = right
                                  ..bottom = bottom
                                  ..left = left,
             key: key);
}

class Flex extends MultiChildRenderObjectWrapper {

  Flex(List<Widget> children, {
    Key key,
    this.direction: FlexDirection.horizontal,
    this.justifyContent: FlexJustifyContent.start,
    this.alignItems: FlexAlignItems.center,
    this.textBaseline
  }) : super(key: key, children: children);

  final FlexDirection direction;
  final FlexJustifyContent justifyContent;
  final FlexAlignItems alignItems;
  final TextBaseline textBaseline;

  RenderFlex createNode() => new RenderFlex(direction: this.direction);
  RenderFlex get root => super.root;

  void syncRenderObject(Widget old) {
    super.syncRenderObject(old);
    root.direction = direction;
    root.justifyContent = justifyContent;
    root.alignItems = alignItems;
    root.textBaseline = textBaseline;
  }

}

class Flexible extends ParentDataNode {
  Flexible({ Key key, int flex: 1, Widget child })
    : super(child, new FlexBoxParentData()..flex = flex, key: key);
}

class Inline extends LeafRenderObjectWrapper {
  Inline({ Key key, this.text }) : super(key: key);

  final InlineBase text;

  RenderParagraph createNode() => new RenderParagraph(text);
  RenderParagraph get root => super.root;

  void syncRenderObject(Widget old) {
    super.syncRenderObject(old);
    root.inline = text;
  }
}

class StyledText extends Component {
  // elements ::= "string" | [<text-style> <elements>*]
  // Where "string" is text to display and text-style is an instance of
  // TextStyle. The text-style applies to all of the elements that follow.
  StyledText({ this.elements, Key key }) : super(key: key);

  final dynamic elements;

  InlineBase _toInline(dynamic element) {
    if (element is String)
      return new InlineText(element);
    if (element is Iterable && element.first is TextStyle)
      return new InlineStyle(element.first, element.skip(1).map(_toInline).toList());
    throw new ArgumentError("invalid elements");
  }

  Widget build() {
    return new Inline(text: _toInline(elements));
  }
}

class Text extends Component {
  Text(this.data, { Key key, TextStyle this.style }) : super(key: key);

  final String data;
  final TextStyle style;

  Widget build() {
    InlineBase text = new InlineText(data);
    TextStyle defaultStyle = DefaultTextStyle.of(this);
    TextStyle combinedStyle;
    if (defaultStyle != null) {
      if (style != null)
        combinedStyle = defaultStyle.merge(style);
      else
        combinedStyle = defaultStyle;
    } else {
      combinedStyle = style;
    }
    if (combinedStyle != null)
      text = new InlineStyle(combinedStyle, [text]);
    return new Inline(text: text);
  }
}

class Image extends LeafRenderObjectWrapper {
  Image({ Key key, this.image, this.width, this.height, this.colorFilter }) : super(key: key);

  final sky.Image image;
  final double width;
  final double height;
  final sky.ColorFilter colorFilter;

  RenderImage createNode() => new RenderImage(image: image, width: width, height: height, colorFilter: colorFilter);
  RenderImage get root => super.root;

  void syncRenderObject(Widget old) {
    super.syncRenderObject(old);
    root.image = image;
    root.width = width;
    root.height = height;
    root.colorFilter = colorFilter;
  }
}

class FutureImage extends StatefulComponent {
  FutureImage({ Key key, this.image, this.width, this.height, this.colorFilter }) : super(key: key);

  Future<sky.Image> image;
  double width;
  double height;
  sky.ColorFilter colorFilter;

  sky.Image _resolvedImage;

  void _resolveImage() {
    image.then((sky.Image resolvedImage) {
      if (!mounted)
        return;
      setState(() {
        _resolvedImage = resolvedImage;
      });
    });
  }

  void didMount() {
    super.didMount();
    _resolveImage();
  }

  void syncFields(FutureImage source) {
    bool needToResolveImage = (image != source.image);
    image = source.image;
    width = source.width;
    height = source.height;
    if (needToResolveImage)
      _resolveImage();
  }

  Widget build() {
    return new Image(
      image: _resolvedImage,
      width: width,
      height: height,
      colorFilter: colorFilter
    );
  }
}

class NetworkImage extends Component {
  NetworkImage({ Key key, this.src, this.width, this.height, this.colorFilter }) : super(key: key);

  final String src;
  final double width;
  final double height;
  final sky.ColorFilter colorFilter;

  Widget build() {
    return new FutureImage(
      image: image_cache.load(src),
      width: width,
      height: height,
      colorFilter: colorFilter
    );
  }
}

class AssetImage extends Component {
  AssetImage({ Key key, this.name, this.bundle, this.width, this.height, this.colorFilter }) : super(key: key);

  final String name;
  final AssetBundle bundle;
  final double width;
  final double height;
  final sky.ColorFilter colorFilter;

  Widget build() {
    return new FutureImage(
      image: bundle.loadImage(name),
      width: width,
      height: height,
      colorFilter: colorFilter
    );
  }
}

class WidgetToRenderBoxAdapter extends LeafRenderObjectWrapper {
  WidgetToRenderBoxAdapter(RenderBox renderBox)
    : renderBox = renderBox,
      super(key: new Key.fromObjectIdentity(renderBox));

  final RenderBox renderBox;

  RenderBox createNode() => this.renderBox;
  RenderBox get root => super.root;

  void syncRenderObject(Widget old) {
    super.syncRenderObject(old);
    if (old != null) {
      assert(old is WidgetToRenderBoxAdapter);
      assert(root == old.root);
    }
  }

  void remove() {
    RenderObjectWrapper ancestor = findAncestorRenderObjectWrapper();
    assert(ancestor is RenderObjectWrapper);
    assert(ancestor.root == root.parent);
    ancestor.detachChildRoot(this);
    super.remove();
  }
}
