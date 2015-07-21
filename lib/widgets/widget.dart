// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:sky' as sky;

import 'package:sky/base/hit_test.dart';
import 'package:sky/mojo/activity.dart' as activity;
import 'package:sky/rendering/box.dart';
import 'package:sky/rendering/object.dart';
import 'package:sky/rendering/sky_binding.dart';

export 'package:sky/rendering/box.dart' show BoxConstraints, BoxDecoration, Border, BorderSide, EdgeDims;
export 'package:sky/rendering/flex.dart' show FlexDirection;
export 'package:sky/rendering/object.dart' show Point, Offset, Size, Rect, Color, Paint, Path;

final bool _shouldLogRenderDuration = false;

typedef Widget Builder();
typedef void WidgetTreeWalker(Widget);

/// A base class for elements of the widget tree
abstract class Widget {

  Widget({ String key }) : _key = key {
    assert(_isConstructedDuringBuild());
  }

  // TODO(jackson): Remove this workaround for limitation of Dart mixins
  Widget._withKey(String key) : _key = key {
    assert(_isConstructedDuringBuild());
  }

  // you should not build the UI tree ahead of time, build it only during build()
  bool _isConstructedDuringBuild() => this is AbstractWidgetRoot || this is App || _inRenderDirtyComponents || _inLayoutCallbackBuilder > 0;

  String _key;

  /// A semantic identifer for this widget
  ///
  /// Keys are used to find matches when synchronizing two widget trees, for
  /// example after a [Component] rebuilds. Without keys, two widgets can match
  /// if their runtimeType matches. With keys, the keys must match as well.
  /// Assigning a key to a widget can improve performance by causing the
  /// framework to sync widgets that share a lot of common structure and can
  /// help match stateful components semantically rather than positionally.
  String get key => _key;

  Widget _parent;

  /// The parent of this widget in the widget tree.
  Widget get parent => _parent;

  bool _mounted = false;
  bool _wasMounted = false;
  bool get mounted => _mounted;
  static bool _notifyingMountStatus = false;
  static List<Widget> _mountedChanged = new List<Widget>();

  /// Called during the synchronizing process to update the widget's parent.
  void setParent(Widget newParent) {
    assert(!_notifyingMountStatus);
    if (_parent == newParent)
      return;
    _parent = newParent;
    if (newParent == null) {
      if (_mounted) {
        _mounted = false;
        _mountedChanged.add(this);
      }
    } else {
      assert(newParent._mounted);
      if (_parent._mounted != _mounted) {
        _mounted = _parent._mounted;
        _mountedChanged.add(this);
      }
    }
  }

  /// Walks the immediate children of this widget
  ///
  /// Override this if you have children and call walker on each child.
  /// Note that you may be called before the child has had its parent
  /// pointer set to point to you. Your walker, and any methods it
  /// invokes on your descendants, should not rely on the ancestor
  /// chain being correctly configured at this point.
  void walkChildren(WidgetTreeWalker walker) { }

  static void _notifyMountStatusChanged() {
    try {
      sky.tracing.begin("Widget._notifyMountStatusChanged");
      _notifyingMountStatus = true;
      for (Widget node in _mountedChanged) {
        if (node._wasMounted != node._mounted) {
          if (node._mounted)
            node.didMount();
          else
            node.didUnmount();
          node._wasMounted = node._mounted;
        }
      }
      _mountedChanged.clear();
    } finally {
      _notifyingMountStatus = false;
      sky.tracing.end("Widget._notifyMountStatusChanged");
    }
  }

  /// Override this function to learn when this [Widget] enters the widget tree.
  void didMount() { }

  /// Override this function to learn when this [Widget] leaves the widget tree.
  void didUnmount() { }

  RenderObject _root;

  /// The underlying [RenderObject] associated with this [Widget].
  RenderObject get root => _root;

  // Subclasses which implements Nodes that become stateful may return true
  // if the node has become stateful and should be retained.
  // This is called immediately before _sync().
  // Component.retainStatefulNodeIfPossible() calls syncFields().
  bool retainStatefulNodeIfPossible(Widget newNode) => false;

  void _sync(Widget old, dynamic slot);
  void updateSlot(dynamic newSlot);
  // 'slot' is the identifier that the ancestor RenderObjectWrapper uses to know
  // where to put this descendant. If you just defer to a child, then make sure
  // to pass them the slot.

  Widget findAncestorRenderObjectWrapper() {
    var ancestor = _parent;
    while (ancestor != null && ancestor is! RenderObjectWrapper)
      ancestor = ancestor._parent;
    return ancestor;
  }

  void remove() {
    _root = null;
    setParent(null);
  }

  void removeChild(Widget node) {
    // Call this when we no longer have a child equivalent to node.
    // For example, when our child has changed type, or has been set to null.
    // Do not call this when our child has been replaced by an equivalent but
    // newer instance that will sync() with the old one, since in that case
    // the subtree starting from the old node, as well as the render tree that
    // belonged to the old node, continue to live on in the replacement node.
    node.remove();
    assert(node.parent == null);
  }

  void detachRoot();

  // Returns the child which should be retained as the child of this node.
  Widget syncChild(Widget newNode, Widget oldNode, dynamic slot) {

    if (newNode == oldNode) {
      assert(newNode == null || newNode.mounted);
      assert(newNode is! RenderObjectWrapper ||
             (newNode is RenderObjectWrapper && newNode._ancestor != null)); // TODO(ianh): Simplify this once the analyzer is cleverer
      if (newNode != null)
        newNode.setParent(this);
      return newNode; // Nothing to do. Subtrees must be identical.
    }

    if (newNode == null) {
      // the child in this slot has gone away
      assert(oldNode.mounted);
      oldNode.detachRoot();
      removeChild(oldNode);
      assert(!oldNode.mounted);
      return null;
    }

    if (oldNode != null) {
      if (oldNode.runtimeType == newNode.runtimeType && oldNode.key == newNode.key) {
        if (oldNode.retainStatefulNodeIfPossible(newNode)) {
          assert(oldNode.mounted);
          assert(!newNode.mounted);
          oldNode.setParent(this);
          oldNode._sync(newNode, slot);
          assert(oldNode.root is RenderObject);
          return oldNode;
        } else {
          oldNode.setParent(null);
        }
      } else {
        assert(oldNode.mounted);
        oldNode.detachRoot();
        removeChild(oldNode);
        oldNode = null;
      }
    }

    assert(oldNode == null || (oldNode.mounted == false && oldNode.parent == null));
    assert(!newNode.mounted);
    newNode.setParent(this);
    newNode._sync(oldNode, slot);
    assert(newNode.root is RenderObject);
    return newNode;
  }

  String _adjustPrefixWithParentCheck(Widget child, String prefix) {
    if (child.parent == this)
      return prefix;
    if (child.parent == null)
      return '$prefix [[DISCONNECTED]] ';
    return '$prefix [[PARENT IS ${child.parent.toStringName()}]] ';
  }

  String toString([String prefix = '', String startPrefix = '']) {
    String childrenString = '';
    List<Widget> children = new List<Widget>();
    walkChildren(children.add);
    if (children.length > 0) {
      Widget lastChild = children.removeLast();
      String nextStartPrefix = prefix + ' +-';
      String nextPrefix = prefix + ' | ';
      for (Widget child in children)
        childrenString += child.toString(nextPrefix, _adjustPrefixWithParentCheck(child, nextStartPrefix));
      nextStartPrefix = prefix + ' \'-';
      nextPrefix = prefix + '   ';
      childrenString += lastChild.toString(nextPrefix, _adjustPrefixWithParentCheck(lastChild, nextStartPrefix));
    }
    return '$startPrefix${toStringName()}\n$childrenString';
  }
  String toStringName() {
    if (key == null)
      return '$runtimeType(unkeyed; hashCode=$hashCode)';
    return '$runtimeType("$key"; hashCode=$hashCode)';
  }

}


// Descendants of TagNode provide a way to tag RenderObjectWrapper and
// Component nodes with annotations, such as event listeners,
// stylistic information, etc.
abstract class TagNode extends Widget {

  TagNode(Widget child, { String key })
    : this.child = child, super(key: key);

  // TODO(jackson): Remove this workaround for limitation of Dart mixins
  TagNode._withKey(Widget child, String key)
    : this.child = child, super._withKey(key);

  Widget child;

  void walkChildren(WidgetTreeWalker walker) {
    if (child != null)
      walker(child);
  }

  void _sync(Widget old, dynamic slot) {
    Widget oldChild = old == null ? null : (old as TagNode).child;
    child = syncChild(child, oldChild, slot);
    assert(child.parent == this);
    assert(child.root != null);
    _root = child.root;
    assert(_root == root); // in case a subclass reintroduces it
  }

  void updateSlot(dynamic newSlot) {
    child.updateSlot(newSlot);
  }

  void remove() {
    if (child != null)
      removeChild(child);
    super.remove();
  }

  void detachRoot() {
    if (child != null)
      child.detachRoot();
  }

}

class ParentDataNode extends TagNode {
  ParentDataNode(Widget child, this.parentData, { String key })
    : super(child, key: key);
  final ParentData parentData;
}

abstract class Inherited extends TagNode {

  Inherited({ String key, Widget child }) : super._withKey(child, key);

  void _sync(Widget old, dynamic slot) {
    if (old != null && syncShouldNotify(old)) {
      final Type ourRuntimeType = runtimeType;
      void notifyChildren(Widget child) {
        if (child is Component &&
            child._dependencies != null &&
            child._dependencies.contains(ourRuntimeType))
          child._dependenciesChanged();
        if (child.runtimeType != ourRuntimeType)
          child.walkChildren(notifyChildren);
      }
      walkChildren(notifyChildren);
    }
    super._sync(old, slot);
  }

  bool syncShouldNotify(Inherited old);

}

typedef void GestureEventListener(sky.GestureEvent e);
typedef void PointerEventListener(sky.PointerEvent e);
typedef void EventListener(sky.Event e);

class Listener extends TagNode  {

  Listener({
    String key,
    Widget child,
    EventListener onWheel,
    GestureEventListener onGestureFlingCancel,
    GestureEventListener onGestureFlingStart,
    GestureEventListener onGestureScrollStart,
    GestureEventListener onGestureScrollUpdate,
    GestureEventListener onGestureTap,
    GestureEventListener onGestureTapDown,
    PointerEventListener onPointerCancel,
    PointerEventListener onPointerDown,
    PointerEventListener onPointerMove,
    PointerEventListener onPointerUp,
    Map<String, EventListener> custom
  }) : listeners = _createListeners(
         onWheel: onWheel,
         onGestureFlingCancel: onGestureFlingCancel,
         onGestureFlingStart: onGestureFlingStart,
         onGestureScrollUpdate: onGestureScrollUpdate,
         onGestureScrollStart: onGestureScrollStart,
         onGestureTap: onGestureTap,
         onGestureTapDown: onGestureTapDown,
         onPointerCancel: onPointerCancel,
         onPointerDown: onPointerDown,
         onPointerMove: onPointerMove,
         onPointerUp: onPointerUp,
         custom: custom
       ),
       super(child, key: key);

  final Map<String, EventListener> listeners;

  static Map<String, EventListener> _createListeners({
    EventListener onWheel,
    GestureEventListener onGestureFlingCancel,
    GestureEventListener onGestureFlingStart,
    GestureEventListener onGestureScrollStart,
    GestureEventListener onGestureScrollUpdate,
    GestureEventListener onGestureTap,
    GestureEventListener onGestureTapDown,
    PointerEventListener onPointerCancel,
    PointerEventListener onPointerDown,
    PointerEventListener onPointerMove,
    PointerEventListener onPointerUp,
    Map<String, EventListener> custom
  }) {
    var listeners = custom != null ?
        new HashMap<String, EventListener>.from(custom) :
        new HashMap<String, EventListener>();

    if (onWheel != null)
      listeners['wheel'] = onWheel;
    if (onGestureFlingCancel != null)
      listeners['gestureflingcancel'] = onGestureFlingCancel;
    if (onGestureFlingStart != null)
      listeners['gestureflingstart'] = onGestureFlingStart;
    if (onGestureScrollStart != null)
      listeners['gesturescrollstart'] = onGestureScrollStart;
    if (onGestureScrollUpdate != null)
      listeners['gesturescrollupdate'] = onGestureScrollUpdate;
    if (onGestureTap != null)
      listeners['gesturetap'] = onGestureTap;
    if (onGestureTapDown != null)
      listeners['gesturetapdown'] = onGestureTapDown;
    if (onPointerCancel != null)
      listeners['pointercancel'] = onPointerCancel;
    if (onPointerDown != null)
      listeners['pointerdown'] = onPointerDown;
    if (onPointerMove != null)
      listeners['pointermove'] = onPointerMove;
    if (onPointerUp != null)
      listeners['pointerup'] = onPointerUp;

    return listeners;
  }

  void _handleEvent(sky.Event e) {
    EventListener listener = listeners[e.type];
    if (listener != null) {
      listener(e);
    }
  }

}

abstract class Component extends Widget {

  Component({ String key })
      : _order = _currentOrder + 1,
        super._withKey(key);

  static Component _currentlyBuilding;
  bool get _isBuilding => _currentlyBuilding == this;

  bool _dirty = true;

  Widget _built;
  dynamic _slot; // cached slot from the last time we were synced

  void updateSlot(dynamic newSlot) {
    _slot = newSlot;
    if (_built != null)
      _built.updateSlot(newSlot);
  }

  void walkChildren(WidgetTreeWalker walker) {
    if (_built != null)
      walker(_built);
  }

  void remove() {
    assert(_built != null);
    assert(root != null);
    removeChild(_built);
    _built = null;
    super.remove();
  }

  void detachRoot() {
    assert(_built != null);
    assert(root != null);
    _built.detachRoot();
  }

  Set<Type> _dependencies;
  Inherited inheritedOfType(Type targetType) {
    if (_dependencies == null)
      _dependencies = new Set<Type>();
    _dependencies.add(targetType);
    Widget ancestor = parent;
    while (ancestor != null && ancestor.runtimeType != targetType)
      ancestor = ancestor.parent;
    return ancestor;
  }
  void _dependenciesChanged() {
    // called by Inherited.sync()
    scheduleBuild();
  }

  // order corresponds to _build_ order, not depth in the tree.
  // All the Components built by a particular other Component will have the
  // same order, regardless of whether one is subsequently inserted
  // into another. The order is used to not tell a Component to
  // rebuild if the Component that it built has itself been rebuilt.
  final int _order;
  static int _currentOrder = 0;

  // There are three cases here:
  // 1) Building for the first time:
  //      assert(_built == null && old == null)
  // 2) Re-building (because a dirty flag got set):
  //      assert(_built != null && old == null)
  // 3) Syncing against an old version
  //      assert(_built == null && old != null)
  void _sync(Component old, dynamic slot) {
    assert(_built == null || old == null);

    updateSlot(slot);

    var oldBuilt;
    if (old == null) {
      oldBuilt = _built;
    } else {
      assert(_built == null);
      oldBuilt = old._built;
    }

    int lastOrder = _currentOrder;
    _currentOrder = _order;
    _currentlyBuilding = this;
    _built = build();
    assert(_built != null);
    _currentlyBuilding = null;
    _currentOrder = lastOrder;

    _built = syncChild(_built, oldBuilt, slot);
    assert(_built != null);
    assert(_built.parent == this);
    _dirty = false;
    _root = _built.root;
    assert(_root == root); // in case a subclass reintroduces it
    assert(root != null);
  }

  void _buildIfDirty() {
    if (!_dirty || !_mounted)
      return;
    assert(root != null);
    _sync(null, _slot);
  }

  void scheduleBuild() {
    if (_isBuilding || _dirty || !_mounted)
      return;
    _dirty = true;
    _scheduleComponentForRender(this);
  }

  Widget build();

}

abstract class StatefulComponent extends Component {

  StatefulComponent({ String key }) : super(key: key);

  bool _disqualifiedFromEverAppearingAgain = false;
  bool _isStateInitialized = false;

  void didMount() {
    assert(!_disqualifiedFromEverAppearingAgain);
    super.didMount();
  }

  void _buildIfDirty() {
    assert(!_disqualifiedFromEverAppearingAgain);
    super._buildIfDirty();
  }

  bool retainStatefulNodeIfPossible(StatefulComponent newNode) {
    assert(!_disqualifiedFromEverAppearingAgain);
    assert(newNode != null);
    assert(runtimeType == newNode.runtimeType);
    assert(key == newNode.key);
    assert(_built != null);
    newNode._disqualifiedFromEverAppearingAgain = true;

    newNode._built = _built;
    _built = null;
    _dirty = true;

    return true;
  }

  // because our retainStatefulNodeIfPossible() method returns true,
  // when _sync is called, our 'old' is actually the new instance that
  // we are to copy state from.
  void _sync(Widget old, dynamic slot) {
    assert(!_disqualifiedFromEverAppearingAgain);
    // TODO(ianh): _sync should only be called once when old == null
    if (old == null && !_isStateInitialized) {
      initState();
      _isStateInitialized = true;
    }
    if (old != null)
      syncFields(old);
    super._sync(old, slot);
  }

  // Stateful components can override initState if they want
  // to do non-trivial work to initialize state. This is
  // always called before build().
  void initState() { }

  // This is called by _sync(). Derived classes should override this
  // method to update `this` to account for the new values the parent
  // passed to `source`. Make sure to call super.syncFields(source)
  // unless you are extending StatefulComponent directly.
  void syncFields(Component source);

  Widget syncChild(Widget node, Widget oldNode, dynamic slot) {
    assert(!_disqualifiedFromEverAppearingAgain);
    return super.syncChild(node, oldNode, slot);
  }

  void setState(Function fn()) {
    assert(!_disqualifiedFromEverAppearingAgain);
    fn();
    scheduleBuild();
  }
}

Set<Component> _dirtyComponents = new Set<Component>();
bool _buildScheduled = false;
bool _inRenderDirtyComponents = false;
int _inLayoutCallbackBuilder = 0;

class LayoutCallbackBuilderHandle { bool _active = true; }
LayoutCallbackBuilderHandle enterLayoutCallbackBuilder() {
  assert(() {
    _inLayoutCallbackBuilder += 1;
    return true;
  });
  return new LayoutCallbackBuilderHandle();
}
void exitLayoutCallbackBuilder(LayoutCallbackBuilderHandle handle) {
  assert(() {
    assert(handle._active);
    handle._active = false;
    _inLayoutCallbackBuilder -= 1;
    return true;
  });
  Widget._notifyMountStatusChanged();
}

List<int> _debugFrameTimes = <int>[];

void _absorbDirtyComponents(List<Component> list) {
  list.addAll(_dirtyComponents);
  _dirtyComponents.clear();
  list.sort((Component a, Component b) => a._order - b._order);
}

void _buildDirtyComponents() {
  Stopwatch sw;
  if (_shouldLogRenderDuration)
    sw = new Stopwatch()..start();

  _inRenderDirtyComponents = true;
  try {
    sky.tracing.begin('Widgets._buildDirtyComponents');
    List<Component> sortedDirtyComponents = new List<Component>();
    _absorbDirtyComponents(sortedDirtyComponents);
    int index = 0;
    while (index < sortedDirtyComponents.length) {
      Component component = sortedDirtyComponents[index];
      component._buildIfDirty();
      if (_dirtyComponents.length > 0) {
        // the following assert verifies that we're not rebuilding anyone twice in one frame
        assert(_dirtyComponents.every((Component component) => !sortedDirtyComponents.contains(component)));
        _absorbDirtyComponents(sortedDirtyComponents);
        index = 0;
      } else {
        index += 1;
      }
    }
  } finally {
    _buildScheduled = false;
    _inRenderDirtyComponents = false;
    sky.tracing.end('Widgets._buildDirtyComponents');
  }

  Widget._notifyMountStatusChanged();

  if (_shouldLogRenderDuration) {
    sw.stop();
    _debugFrameTimes.add(sw.elapsedMicroseconds);
    if (_debugFrameTimes.length >= 1000) {
      _debugFrameTimes.sort();
      const int i = 99;
      print('_buildDirtyComponents: ${i+1}th fastest frame out of the last ${_debugFrameTimes.length}: ${_debugFrameTimes[i]} microseconds');
      _debugFrameTimes.clear();
    }
  }
}

void _scheduleComponentForRender(Component c) {
  _dirtyComponents.add(c);
  if (!_buildScheduled) {
    _buildScheduled = true;
    new Future.microtask(_buildDirtyComponents);
  }
}


// RenderObjectWrappers correspond to a desired state of a RenderObject.
// They are fully immutable, with one exception: A Widget which is a
// Component which lives within an MultiChildRenderObjectWrapper's
// children list, may be replaced with the "old" instance if it has
// become stateful.
abstract class RenderObjectWrapper extends Widget {

  RenderObjectWrapper({ String key }) : super(key: key);

  RenderObject createNode();

  static final Map<RenderObject, RenderObjectWrapper> _nodeMap =
      new HashMap<RenderObject, RenderObjectWrapper>();
  static RenderObjectWrapper _getMounted(RenderObject node) => _nodeMap[node];

  RenderObjectWrapper _ancestor;
  void insertChildRoot(RenderObjectWrapper child, dynamic slot);
  void detachChildRoot(RenderObjectWrapper child);

  void retainStatefulRenderObjectWrapper(RenderObjectWrapper newNode) {
    newNode._root = _root;
    newNode._ancestor = _ancestor;
  }

  void _sync(RenderObjectWrapper old, dynamic slot) {
    // TODO(abarth): We should split RenderObjectWrapper into two pieces so that
    //               RenderViewObject doesn't need to inherit all this code it
    //               doesn't need.
    assert(parent != null || this is RenderViewWrapper);
    if (old == null) {
      _root = createNode();
      assert(_root != null);
      _ancestor = findAncestorRenderObjectWrapper();
      if (_ancestor is RenderObjectWrapper)
        _ancestor.insertChildRoot(this, slot);
    } else {
      assert(old is RenderObjectWrapper);
      _root = old.root;
      _ancestor = old._ancestor;
      assert(_root != null);
    }
    assert(_root == root); // in case a subclass reintroduces it
    assert(root != null);
    assert(mounted);
    _nodeMap[root] = this;
    syncRenderObject(old);
  }

  void updateSlot(dynamic newSlot) {
    // We never use the slot except during sync(), in which
    // case our parent is handing it to us anyway.
    // We don't need to propagate this to our children, since
    // we give them their own slots for them to fit into us.
  }

  void syncRenderObject(RenderObjectWrapper old) {
    ParentData parentData = null;
    Widget ancestor = parent;
    while (ancestor != null && ancestor is! RenderObjectWrapper) {
      if (ancestor is ParentDataNode && ancestor.parentData != null) {
        if (parentData != null)
          parentData.merge(ancestor.parentData); // this will throw if the types aren't the same
        else
          parentData = ancestor.parentData;
      }
      ancestor = ancestor.parent;
    }
    if (parentData != null) {
      assert(root.parentData != null);
      root.parentData.merge(parentData); // this will throw if the types aren't appropriate
      if (parent.root != null)
        parent.root.markNeedsLayout();
    }
  }

  void remove() {
    assert(root != null);
    _nodeMap.remove(root);
    super.remove();
  }

  void detachRoot() {
    assert(_ancestor != null);
    assert(root != null);
    _ancestor.detachChildRoot(this);
  }

}

abstract class LeafRenderObjectWrapper extends RenderObjectWrapper {

  LeafRenderObjectWrapper({ String key }) : super(key: key);

  void insertChildRoot(RenderObjectWrapper child, dynamic slot) {
    assert(false);
  }

  void detachChildRoot(RenderObjectWrapper child) {
    assert(false);
  }

}

abstract class OneChildRenderObjectWrapper extends RenderObjectWrapper {

  OneChildRenderObjectWrapper({ String key, Widget child })
    : _child = child, super(key: key);

  Widget _child;
  Widget get child => _child;

  void walkChildren(WidgetTreeWalker walker) {
    if (child != null)
      walker(child);
  }

  void syncRenderObject(RenderObjectWrapper old) {
    super.syncRenderObject(old);
    Widget oldChild = old == null ? null : (old as OneChildRenderObjectWrapper).child;
    Widget newChild = child;
    _child = syncChild(newChild, oldChild, null);
    assert((newChild == null && child == null) || (newChild != null && child.parent == this));
    assert(oldChild == null || child == oldChild || oldChild.parent == null);
  }

  void insertChildRoot(RenderObjectWrapper child, dynamic slot) {
    final root = this.root; // TODO(ianh): Remove this once the analyzer is cleverer
    assert(root is RenderObjectWithChildMixin);
    assert(slot == null);
    root.child = child.root;
    assert(root == this.root); // TODO(ianh): Remove this once the analyzer is cleverer
  }

  void detachChildRoot(RenderObjectWrapper child) {
    final root = this.root; // TODO(ianh): Remove this once the analyzer is cleverer
    assert(root is RenderObjectWithChildMixin);
    assert(root.child == child.root);
    root.child = null;
    assert(root == this.root); // TODO(ianh): Remove this once the analyzer is cleverer
  }

  void remove() {
    if (child != null)
      removeChild(child);
    super.remove();
  }
}

abstract class MultiChildRenderObjectWrapper extends RenderObjectWrapper {

  // In MultiChildRenderObjectWrapper subclasses, slots are RenderObject nodes
  // to use as the "insert before" sibling in ContainerRenderObjectMixin.add() calls

  MultiChildRenderObjectWrapper({ String key, List<Widget> children })
    : this.children = children == null ? const [] : children,
      super(key: key) {
    assert(!_debugHasDuplicateIds());
  }

  final List<Widget> children;

  void walkChildren(WidgetTreeWalker walker) {
    for (Widget child in children)
      walker(child);
  }

  void insertChildRoot(RenderObjectWrapper child, dynamic slot) {
    final root = this.root; // TODO(ianh): Remove this once the analyzer is cleverer
    assert(slot == null || slot is RenderObject);
    assert(root is ContainerRenderObjectMixin);
    root.add(child.root, before: slot);
    assert(root == this.root); // TODO(ianh): Remove this once the analyzer is cleverer
  }

  void detachChildRoot(RenderObjectWrapper child) {
    final root = this.root; // TODO(ianh): Remove this once the analyzer is cleverer
    assert(root is ContainerRenderObjectMixin);
    assert(child.root.parent == root);
    root.remove(child.root);
    assert(root == this.root); // TODO(ianh): Remove this once the analyzer is cleverer
  }

  void remove() {
    assert(children != null);
    for (var child in children) {
      assert(child != null);
      removeChild(child);
    }
    super.remove();
  }

  bool _debugHasDuplicateIds() {
    var idSet = new HashSet<String>();
    for (var child in children) {
      assert(child != null);
      if (child.key == null)
        continue; // when these nodes are reordered, we just reassign the data

      if (!idSet.add(child.key)) {
        throw '''If multiple keyed nodes exist as children of another node, they must have unique keys. $this has duplicate child key "${child.key}".''';
      }
    }
    return false;
  }

  void syncRenderObject(MultiChildRenderObjectWrapper old) {
    super.syncRenderObject(old);

    final root = this.root; // TODO(ianh): Remove this once the analyzer is cleverer
    if (root is! ContainerRenderObjectMixin)
      return;

    var startIndex = 0;
    var endIndex = children.length;

    var oldChildren = old == null ? [] : old.children;
    var oldStartIndex = 0;
    var oldEndIndex = oldChildren.length;

    RenderObject nextSibling = null;
    Widget currentNode = null;
    Widget oldNode = null;

    void sync(int atIndex) {
      children[atIndex] = syncChild(currentNode, oldNode, nextSibling);
      assert(children[atIndex] != null);
      assert(children[atIndex].parent == this);
      if (atIndex > 0)
        children[atIndex-1].updateSlot(children[atIndex].root);
    }

    // Scan backwards from end of list while nodes can be directly synced
    // without reordering.
    while (endIndex > startIndex && oldEndIndex > oldStartIndex) {
      currentNode = children[endIndex - 1];
      oldNode = oldChildren[oldEndIndex - 1];

      if (currentNode.runtimeType != oldNode.runtimeType || currentNode.key != oldNode.key) {
        break;
      }

      endIndex--;
      oldEndIndex--;
      sync(endIndex);
      nextSibling = children[endIndex].root;
    }

    HashMap<String, Widget> oldNodeIdMap = null;

    bool oldNodeReordered(String key) {
      return oldNodeIdMap != null &&
             oldNodeIdMap.containsKey(key) &&
             oldNodeIdMap[key] == null;
    }

    void advanceOldStartIndex() {
      oldStartIndex++;
      while (oldStartIndex < oldEndIndex &&
             oldNodeReordered(oldChildren[oldStartIndex].key)) {
        oldStartIndex++;
      }
    }

    void ensureOldIdMap() {
      if (oldNodeIdMap != null)
        return;

      oldNodeIdMap = new HashMap<String, Widget>();
      for (int i = oldStartIndex; i < oldEndIndex; i++) {
        var node = oldChildren[i];
        if (node.key != null)
          oldNodeIdMap.putIfAbsent(node.key, () => node);
      }
    }

    bool searchForOldNode() {
      if (currentNode.key == null)
        return false; // never re-order these nodes

      ensureOldIdMap();
      oldNode = oldNodeIdMap[currentNode.key];
      if (oldNode == null)
        return false;

      oldNodeIdMap[currentNode.key] = null; // mark it reordered
      assert(root is ContainerRenderObjectMixin);
      assert(old.root is ContainerRenderObjectMixin);
      assert(oldNode.root != null);

      if (old.root == root) {
        root.move(oldNode.root, before: nextSibling);
      } else {
        (old.root as ContainerRenderObjectMixin).remove(oldNode.root); // TODO(ianh): Remove cast once the analyzer is cleverer
        root.add(oldNode.root, before: nextSibling);
      }

      return true;
    }

    // Scan forwards, this time we may re-order;
    nextSibling = root.firstChild;
    while (startIndex < endIndex && oldStartIndex < oldEndIndex) {
      currentNode = children[startIndex];
      oldNode = oldChildren[oldStartIndex];

      if (currentNode.runtimeType == oldNode.runtimeType && currentNode.key == oldNode.key) {
        nextSibling = root.childAfter(nextSibling);
        sync(startIndex);
        startIndex++;
        advanceOldStartIndex();
        continue;
      }

      oldNode = null;
      searchForOldNode();
      sync(startIndex);
      startIndex++;
    }

    // New insertions
    oldNode = null;
    while (startIndex < endIndex) {
      currentNode = children[startIndex];
      sync(startIndex);
      startIndex++;
    }

    // Removals
    currentNode = null;
    while (oldStartIndex < oldEndIndex) {
      oldNode = oldChildren[oldStartIndex];
      syncChild(null, oldNode, null);
      assert(oldNode.parent == null);
      advanceOldStartIndex();
    }

    assert(root == this.root); // TODO(ianh): Remove this once the analyzer is cleverer
  }

}

class WidgetSkyBinding extends SkyBinding {

  WidgetSkyBinding({ RenderView renderViewOverride: null })
      : super(renderViewOverride: renderViewOverride);

  static void initWidgetSkyBinding({ RenderView renderViewOverride: null }) {
    if (SkyBinding.instance == null)
      new WidgetSkyBinding(renderViewOverride: renderViewOverride);
    assert(SkyBinding.instance is WidgetSkyBinding);
  }

  void dispatchEvent(sky.Event event, HitTestResult result) {
    assert(SkyBinding.instance == this);
    super.dispatchEvent(event, result);
    for (HitTestEntry entry in result.path.reversed) {
      Widget target = RenderObjectWrapper._getMounted(entry.target);
      if (target == null)
        continue;
      RenderObject targetRoot = target.root;
      while (target != null && target.root == targetRoot) {
        if (target is Listener)
          target._handleEvent(event);
        target = target._parent;
      }
    }
  }

}

abstract class App extends StatefulComponent {

  App({ String key }) : super(key: key);

  void _handleEvent(sky.Event event) {
    if (event.type == 'back')
      onBack();
  }

  void didMount() {
    super.didMount();
    SkyBinding.instance.addEventListener(_handleEvent);
  }

  void didUnmount() {
    super.didUnmount();
    SkyBinding.instance.removeEventListener(_handleEvent);
  }

  void syncFields(Component source) { }

  // Override this to handle back button behavior in your app
  // Call super.onBack() to finish the activity
  void onBack() {
    activity.finishCurrentActivity();
  }
}

abstract class AbstractWidgetRoot extends StatefulComponent {

  AbstractWidgetRoot() {
    _mounted = true;
    _scheduleComponentForRender(this);
  }

  void syncFields(AbstractWidgetRoot source) {
    assert(false);
    // if we get here, it implies that we have a parent
  }

  void _buildIfDirty() {
    assert(_dirty);
    assert(_mounted);
    assert(parent == null);
    _sync(null, null);
  }

}

class RenderViewWrapper extends OneChildRenderObjectWrapper {
  RenderViewWrapper({ String key, Widget child }) : super(key: key, child: child);
  RenderView get root => super.root;
  RenderView createNode() => SkyBinding.instance.renderView;
}

class AppContainer extends AbstractWidgetRoot {
  AppContainer(this.app) {
    assert(SkyBinding.instance is WidgetSkyBinding);
  }
  final App app;
  Widget build() => new RenderViewWrapper(child: app);
}

AppContainer _container;
void runApp(App app, { RenderView renderViewOverride, bool enableProfilingLoop: false }) {
  WidgetSkyBinding.initWidgetSkyBinding(renderViewOverride: renderViewOverride);
  _container = new AppContainer(app);
  if (enableProfilingLoop) {
    new Timer.periodic(const Duration(milliseconds: 20), (_) {
      app.scheduleBuild();
    });
  }
}
void debugDumpApp() {
  if (_container != null)
    _container.toString().split('\n').forEach(print);
  else
    print("runApp() not yet called");
}


class RenderBoxToWidgetAdapter extends AbstractWidgetRoot {

  RenderBoxToWidgetAdapter(
    RenderObjectWithChildMixin<RenderBox> container,
    this.builder
  ) : _container = container, super() {
    assert(builder != null);
  }

  RenderObjectWithChildMixin<RenderBox> _container;
  RenderObjectWithChildMixin<RenderBox> get container => _container;
  void set container(RenderObjectWithChildMixin<RenderBox> value) {
    if (_container != value) {
      assert(value.child == null);
      if (root != null) {
        assert(_container.child == root);
        _container.child = null;
      }
      _container = value;
      if (root != null) {
        _container.child = root;
        assert(_container.child == root);
      }
    }
  }

  final Builder builder;

  void _buildIfDirty() {
    super._buildIfDirty();
    if (root.parent == null) {
      // we haven't attached it yet
      assert(_container.child == null);
      _container.child = root;
    }
    assert(root.parent == _container);
  }

  Widget build() => builder();
}
