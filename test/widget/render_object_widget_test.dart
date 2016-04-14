// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

final BoxDecoration kBoxDecorationA = new BoxDecoration();
final BoxDecoration kBoxDecorationB = new BoxDecoration();
final BoxDecoration kBoxDecorationC = new BoxDecoration();

class TestWidget extends StatelessWidget {
  const TestWidget({ this.child });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class TestOrientedBox extends SingleChildRenderObjectWidget {
  TestOrientedBox({ Key key, Widget child }) : super(key: key, child: child);

  Decoration _getDecoration(BuildContext context) {
    switch (MediaQuery.of(context).orientation) {
      case Orientation.landscape:
        return new BoxDecoration(backgroundColor: const Color(0xFF00FF00));
      case Orientation.portrait:
        return new BoxDecoration(backgroundColor: const Color(0xFF0000FF));
    }
  }

  @override
  RenderDecoratedBox createRenderObject(BuildContext context) => new RenderDecoratedBox(decoration: _getDecoration(context));

  @override
  void updateRenderObject(BuildContext context, RenderDecoratedBox renderObject) {
    renderObject.decoration = _getDecoration(context);
  }
}

void main() {
  test('RenderObjectWidget smoke test', () {
    testElementTree((ElementTreeTester tester) {
      tester.pumpWidget(new DecoratedBox(decoration: kBoxDecorationA));
      SingleChildRenderObjectElement element =
          tester.findElement((Element element) => element is SingleChildRenderObjectElement);
      expect(element, isNotNull);
      expect(element.renderObject is RenderDecoratedBox, isTrue);
      RenderDecoratedBox renderObject = element.renderObject;
      expect(renderObject.decoration, equals(kBoxDecorationA));
      expect(renderObject.position, equals(DecorationPosition.background));

      tester.pumpWidget(new DecoratedBox(decoration: kBoxDecorationB));
      element = tester.findElement((Element element) => element is SingleChildRenderObjectElement);
      expect(element, isNotNull);
      expect(element.renderObject is RenderDecoratedBox, isTrue);
      renderObject = element.renderObject;
      expect(renderObject.decoration, equals(kBoxDecorationB));
      expect(renderObject.position, equals(DecorationPosition.background));
    });
  });

  test('RenderObjectWidget can add and remove children', () {
    testElementTree((ElementTreeTester tester) {

      void checkFullTree() {
        SingleChildRenderObjectElement element =
            tester.findElement((Element element) => element is SingleChildRenderObjectElement);
        expect(element, isNotNull);
        expect(element.renderObject is RenderDecoratedBox, isTrue);
        RenderDecoratedBox renderObject = element.renderObject;
        expect(renderObject.decoration, equals(kBoxDecorationA));
        expect(renderObject.position, equals(DecorationPosition.background));
        expect(renderObject.child, isNotNull);
        expect(renderObject.child is RenderDecoratedBox, isTrue);
        RenderDecoratedBox child = renderObject.child;
        expect(child.decoration, equals(kBoxDecorationB));
        expect(child.position, equals(DecorationPosition.background));
        expect(child.child, isNull);
      }

      void childBareTree() {
        SingleChildRenderObjectElement element =
            tester.findElement((Element element) => element is SingleChildRenderObjectElement);
        expect(element, isNotNull);
        expect(element.renderObject is RenderDecoratedBox, isTrue);
        RenderDecoratedBox renderObject = element.renderObject;
        expect(renderObject.decoration, equals(kBoxDecorationA));
        expect(renderObject.position, equals(DecorationPosition.background));
        expect(renderObject.child, isNull);
      }

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA,
        child: new DecoratedBox(
          decoration: kBoxDecorationB
        )
      ));

      checkFullTree();

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA,
        child: new TestWidget(
          child: new DecoratedBox(
            decoration: kBoxDecorationB
          )
        )
      ));

      checkFullTree();

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA,
        child: new DecoratedBox(
          decoration: kBoxDecorationB
        )
      ));

      checkFullTree();

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA
      ));

      childBareTree();

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA,
        child: new TestWidget(
          child: new TestWidget(
            child: new DecoratedBox(
              decoration: kBoxDecorationB
            )
          )
        )
      ));

      checkFullTree();

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA
      ));

      childBareTree();
    });
  });

  test('Detached render tree is intact', () {
    testElementTree((ElementTreeTester tester) {

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA,
        child: new DecoratedBox(
          decoration: kBoxDecorationB,
          child: new DecoratedBox(
            decoration: kBoxDecorationC
          )
        )
      ));

      SingleChildRenderObjectElement element =
          tester.findElement((Element element) => element is SingleChildRenderObjectElement);
      expect(element.renderObject is RenderDecoratedBox, isTrue);
      RenderDecoratedBox parent = element.renderObject;
      expect(parent.child is RenderDecoratedBox, isTrue);
      RenderDecoratedBox child = parent.child;
      expect(child.decoration, equals(kBoxDecorationB));
      expect(child.child is RenderDecoratedBox, isTrue);
      RenderDecoratedBox grandChild = child.child;
      expect(grandChild.decoration, equals(kBoxDecorationC));
      expect(grandChild.child, isNull);

      tester.pumpWidget(new DecoratedBox(
        decoration: kBoxDecorationA
      ));

      element =
          tester.findElement((Element element) => element is SingleChildRenderObjectElement);
      expect(element.renderObject is RenderDecoratedBox, isTrue);
      expect(element.renderObject, equals(parent));
      expect(parent.child, isNull);

      expect(child.parent, isNull);
      expect(child.decoration, equals(kBoxDecorationB));
      expect(child.child, equals(grandChild));
      expect(grandChild.parent, equals(child));
      expect(grandChild.decoration, equals(kBoxDecorationC));
      expect(grandChild.child, isNull);
    });
  });

  test('Can watch inherited widgets', () {
    testElementTree((ElementTreeTester tester) {
      Key boxKey = new UniqueKey();
      TestOrientedBox box = new TestOrientedBox(key: boxKey);

      tester.pumpWidget(new MediaQuery(
        data: new MediaQueryData(size: const Size(400.0, 300.0)),
        child: box
      ));

      RenderDecoratedBox renderBox = tester.findElementByKey(boxKey).renderObject;
      BoxDecoration decoration = renderBox.decoration;
      expect(decoration.backgroundColor, equals(new Color(0xFF00FF00)));

      tester.pumpWidget(new MediaQuery(
        data: new MediaQueryData(size: const Size(300.0, 400.0)),
        child: box
      ));

      decoration = renderBox.decoration;
      expect(decoration.backgroundColor, equals(new Color(0xFF0000FF)));
    });
  });
}
