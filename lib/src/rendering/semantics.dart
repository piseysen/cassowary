// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';
import 'package:sky_services/semantics/semantics.mojom.dart' as mojom;
import 'package:vector_math/vector_math_64.dart';

import 'node.dart';

enum SemanticAction {
  tap,
  longPress,
  scrollLeft,
  scrollRight,
  scrollUp,
  scrollDown,
  increase,
  decrease,
}

/// Interface for [RenderObject]s to implement when they want to support
/// being tapped, etc.
///
/// These handlers will only be called if the relevant flag is set
/// (e.g. [handleSemanticTap]() will only be called if
/// [SemanticsNode.canBeTapped] is true, [handleSemanticScrollDown]() will only
/// be called if [SemanticsNode.canBeScrolledVertically] is true, etc).
abstract class SemanticActionHandler { // ignore: one_member_abstracts
  void performAction(SemanticAction action);
}

/// The type of function returned by [RenderObject.getSemanticAnnotators()].
///
/// These callbacks are called with the [SemanticsNode] object that
/// corresponds to the [RenderObject]. (One [SemanticsNode] can
/// correspond to multiple [RenderObject] objects.)
///
/// See [RenderObject.getSemanticAnnotators()] for details on the
/// contract that semantic annotators must follow.
typedef void SemanticAnnotator(SemanticsNode semantics);

enum _SemanticFlags {
  mergeAllDescendantsIntoThisNode,
  inheritedMergeAllDescendantsIntoThisNode, // whether an ancestor had mergeAllDescendantsIntoThisNode set
  hasCheckedState,
  isChecked,
}

/// Signature for a function that is called for each [SemanticsNode].
///
/// Return false to stop visiting nodes.
typedef bool SemanticsNodeVisitor(SemanticsNode node);

/// A node that represents some semantic data.
///
/// The semantics tree is maintained during the semantics phase of the pipeline
/// (i.e., during [PipelineOwner.flushSemantics]), which happens after
/// compositing. The semantics tree is then uploaded into the engine for use
/// by assistive technology.
class SemanticsNode extends AbstractNode {
  /// Creates a semantic node.
  ///
  /// Each semantic node has a unique identifier that is assigned when the node
  /// is created.
  SemanticsNode({
    SemanticActionHandler handler
  }) : _id = _generateNewId(),
       _actionHandler = handler;

  /// Creates a semantic node to represent the root of the semantics tree.
  ///
  /// The root node is assigned an identifier of zero.
  SemanticsNode.root({
    SemanticActionHandler handler,
    SemanticsOwner owner
  }) : _id = 0,
       _actionHandler = handler {
    attach(owner);
  }

  static int _lastIdentifier = 0;
  static int _generateNewId() {
    _lastIdentifier += 1;
    return _lastIdentifier;
  }

  final int _id;
  final SemanticActionHandler _actionHandler;


  // GEOMETRY
  // These are automatically handled by RenderObject's own logic

  /// The transform from this node's coordinate system to its parent's coordinate system.
  ///
  /// By default, the transform is null, which represents the identity
  /// transformation (i.e., that this node has the same coorinate system as its
  /// parent).
  Matrix4 get transform => _transform;
  Matrix4 _transform;
  set transform (Matrix4 value) {
    if (!MatrixUtils.matrixEquals(_transform, value)) {
      _transform = value;
      _markDirty();
    }
  }

  /// The bounding box for this node in its coordinate system.
  Rect get rect => _rect;
  Rect _rect = Rect.zero;
  set rect (Rect value) {
    assert(value != null);
    if (_rect != value) {
      _rect = value;
      _markDirty();
    }
  }

  /// Whether [rect] might have been influenced by clips applied by ancestors.
  bool wasAffectedByClip = false;


  // FLAGS AND LABELS
  // These are supposed to be set by SemanticAnnotator obtained from getSemanticAnnotators

  final Set<SemanticAction> _actions = new Set<SemanticAction>();

  /// Adds the given action to the set of semantic actions.
  ///
  /// If the user chooses to perform an action,
  /// [SemanticActionHandler.performAction] will be called with the chosen
  /// action.
  void addAction(SemanticAction action) {
    if (_actions.add(action))
      _markDirty();
  }

  /// Adds the [SemanticAction.scrollLeft] and [SemanticAction.scrollRight] actions.
  void addHorizontalScrollingActions() {
    addAction(SemanticAction.scrollLeft);
    addAction(SemanticAction.scrollRight);
  }

  /// Adds the [SemanticAction.scrollUp] and [SemanticAction.scrollDown] actions.
  void addVerticalScrollingActions() {
    addAction(SemanticAction.scrollUp);
    addAction(SemanticAction.scrollDown);
  }

  /// Adds the [SemanticAction.increase] and [SemanticAction.decrease] actions.
  void addAdjustmentActions() {
    addAction(SemanticAction.increase);
    addAction(SemanticAction.decrease);
  }

  bool _hasAction(SemanticAction action) {
    return _actionHandler != null && _actions.contains(action);
  }

  BitField<_SemanticFlags> _flags = new BitField<_SemanticFlags>.filled(_SemanticFlags.values.length, false);

  void _setFlag(_SemanticFlags flag, bool value, { bool needsHandler: false }) {
    assert(value != null);
    assert((!needsHandler) || (_actionHandler != null) || (value == false));
    if (_flags[flag] != value) {
      _flags[flag] = value;
      _markDirty();
    }
  }

  /// Whether all this node and all of its descendants should be treated as one logical entity.
  bool get mergeAllDescendantsIntoThisNode => _flags[_SemanticFlags.mergeAllDescendantsIntoThisNode];
  set mergeAllDescendantsIntoThisNode(bool value) => _setFlag(_SemanticFlags.mergeAllDescendantsIntoThisNode, value);

  bool get _inheritedMergeAllDescendantsIntoThisNode => _flags[_SemanticFlags.inheritedMergeAllDescendantsIntoThisNode];
  set _inheritedMergeAllDescendantsIntoThisNode(bool value) => _setFlag(_SemanticFlags.inheritedMergeAllDescendantsIntoThisNode, value);

  bool get _shouldMergeAllDescendantsIntoThisNode => mergeAllDescendantsIntoThisNode || _inheritedMergeAllDescendantsIntoThisNode;

  /// Whether this node has Boolean state that can be controlled by the user.
  bool get hasCheckedState => _flags[_SemanticFlags.hasCheckedState];
  set hasCheckedState(bool value) => _setFlag(_SemanticFlags.hasCheckedState, value);

  /// If this node has Boolean state that can be controlled by the user, whether that state is on or off, cooresponding to `true` and `false`, respectively.
  bool get isChecked => _flags[_SemanticFlags.isChecked];
  set isChecked(bool value) => _setFlag(_SemanticFlags.isChecked, value);

  /// A textual description of this node.
  String get label => _label;
  String _label = '';
  set label(String value) {
    assert(value != null);
    if (_label != value) {
      _label = value;
      _markDirty();
    }
  }

  /// Restore this node to its default state.
  void reset() {
    bool hadInheritedMergeAllDescendantsIntoThisNode = _inheritedMergeAllDescendantsIntoThisNode;
    _actions.clear();
    _flags.reset();
    if (hadInheritedMergeAllDescendantsIntoThisNode)
      _inheritedMergeAllDescendantsIntoThisNode = true;
    _label = '';
    _markDirty();
  }

  List<SemanticsNode> _newChildren;

  /// Append the given children as children of this node.
  void addChildren(Iterable<SemanticsNode> children) {
    _newChildren ??= <SemanticsNode>[];
    _newChildren.addAll(children);
    // we do the asserts afterwards because children is an Iterable
    // and doing the asserts before would mean the behavior is
    // different in checked mode vs release mode (if you walk an
    // iterator after having reached the end, it'll just start over;
    // the values are not cached).
    assert(!_newChildren.any((SemanticsNode child) => child == this));
    assert(() {
      SemanticsNode ancestor = this;
      while (ancestor.parent is SemanticsNode)
        ancestor = ancestor.parent;
      assert(!_newChildren.any((SemanticsNode child) => child == ancestor));
      return true;
    });
    assert(() {
      Set<SemanticsNode> seenChildren = new Set<SemanticsNode>();
      for (SemanticsNode child in _newChildren)
        assert(seenChildren.add(child)); // check for duplicate adds
      return true;
    });
  }

  List<SemanticsNode> _children;

  /// Whether this node has a non-zero number of children.
  bool get hasChildren => _children?.isNotEmpty ?? false;
  bool _dead = false;

  /// Called during the compilation phase after all the children of this node have been compiled.
  ///
  /// This function lets the semantic node respond to all the changes to its
  /// child list for the given frame at once instead of needing to process the
  /// changes incrementally as new children are compiled.
  void finalizeChildren() {
    if (_children != null) {
      for (SemanticsNode child in _children)
        child._dead = true;
    }
    if (_newChildren != null) {
      for (SemanticsNode child in _newChildren)
        child._dead = false;
    }
    bool sawChange = false;
    if (_children != null) {
      for (SemanticsNode child in _children) {
        if (child._dead) {
          if (child.parent == this) {
            // we might have already had our child stolen from us by
            // another node that is deeper in the tree.
            dropChild(child);
          }
          sawChange = true;
        }
      }
    }
    if (_newChildren != null) {
      for (SemanticsNode child in _newChildren) {
        if (child.parent != this) {
          if (child.parent != null) {
            // we're rebuilding the tree from the bottom up, so it's possible
            // that our child was, in the last pass, a child of one of our
            // ancestors. In that case, we drop the child eagerly here.
            // TODO(ianh): Find a way to assert that the same node didn't
            // actually appear in the tree in two places.
            child.parent?.dropChild(child);
          }
          assert(!child.attached);
          adoptChild(child);
          sawChange = true;
        }
      }
    }
    List<SemanticsNode> oldChildren = _children;
    _children = _newChildren;
    oldChildren?.clear();
    _newChildren = oldChildren;
    if (sawChange)
      _markDirty();
  }

  @override
  SemanticsOwner get owner => super.owner;

  @override
  SemanticsNode get parent => super.parent;

  @override
  void redepthChildren() {
    if (_children != null) {
      for (SemanticsNode child in _children)
        redepthChild(child);
    }
  }

  // Visits all the descendants of this node, calling visitor for each one, until
  // visitor returns false. Returns true if all the visitor calls returned true,
  // otherwise returns false.
  bool _visitDescendants(SemanticsNodeVisitor visitor) {
    if (_children != null) {
      for (SemanticsNode child in _children) {
        if (!visitor(child) || !child._visitDescendants(visitor))
          return false;
      }
    }
    return true;
  }

  @override
  void attach(SemanticsOwner owner) {
    super.attach(owner);
    assert(!owner._nodes.containsKey(_id));
    owner._nodes[_id] = this;
    owner._detachedNodes.remove(this);
    if (_dirty) {
      _dirty = false;
      _markDirty();
    }
    if (parent != null)
      _inheritedMergeAllDescendantsIntoThisNode = parent._shouldMergeAllDescendantsIntoThisNode;
    if (_children != null) {
      for (SemanticsNode child in _children)
        child.attach(owner);
    }
  }

  @override
  void detach() {
    assert(owner._nodes.containsKey(_id));
    assert(!owner._detachedNodes.contains(this));
    owner._nodes.remove(_id);
    owner._detachedNodes.add(this);
    super.detach();
    if (_children != null) {
      for (SemanticsNode child in _children)
        child.detach();
    }
  }

  bool _dirty = false;
  void _markDirty() {
    if (_dirty)
      return;
    _dirty = true;
    if (attached) {
      assert(!owner._dirtyNodes.contains(this));
      assert(!owner._detachedNodes.contains(this));
      owner._dirtyNodes.add(this);
    }
  }

  mojom.SemanticsNode _serialize() {
    mojom.SemanticsNode result = new mojom.SemanticsNode();
    result.id = _id;
    if (_dirty) {
      // We could be even more efficient about not sending data here, by only
      // sending the bits that are dirty (tracking the geometry, flags, strings,
      // and children separately). For now, we send all or nothing.
      result.geometry = new mojom.SemanticGeometry();
      result.geometry.transform = transform?.storage;
      result.geometry.top = rect.top;
      result.geometry.left = rect.left;
      result.geometry.width = math.max(rect.width, 0.0);
      result.geometry.height = math.max(rect.height, 0.0);
      result.flags = new mojom.SemanticFlags();
      result.flags.hasCheckedState = hasCheckedState;
      result.flags.isChecked = isChecked;
      result.strings = new mojom.SemanticStrings();
      result.strings.label = label;
      List<mojom.SemanticsNode> children = <mojom.SemanticsNode>[];
      Set<SemanticAction> mergedActions = new Set<SemanticAction>();
      mergedActions.addAll(_actions);
      if (_shouldMergeAllDescendantsIntoThisNode) {
        _visitDescendants((SemanticsNode node) {
          mergedActions.addAll(node._actions);
          result.flags.hasCheckedState = result.flags.hasCheckedState || node.hasCheckedState;
          result.flags.isChecked = result.flags.isChecked || node.isChecked;
          if (node.label != '')
            result.strings.label = result.strings.label.isNotEmpty ? '${result.strings.label}\n${node.label}' : node.label;
          node._dirty = false;
          return true; // continue walk
        });
        // and we pretend to have no children
      } else {
        if (_children != null) {
          for (SemanticsNode child in _children)
            children.add(child._serialize());
        }
      }
      result.children = children;
      result.actions = <int>[];
      for (SemanticAction action in mergedActions)
        result.actions.add(action.index);
      _dirty = false;
    }
    return result;
  }

  @override
  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.write('$runtimeType($_id');
    if (_dirty)
      buffer.write(" (${ owner != null && owner._dirtyNodes.contains(this) ? 'dirty' : 'STALE' })");
    if (_shouldMergeAllDescendantsIntoThisNode)
      buffer.write(' (leaf merge)');
    buffer.write('; $rect');
    if (wasAffectedByClip)
      buffer.write(' (clipped)');
    for (SemanticAction action in _actions) {
      buffer.write('; $action');
    }
    if (hasCheckedState) {
      if (isChecked)
        buffer.write('; checked');
      else
        buffer.write('; unchecked');
    }
    if (label.isNotEmpty)
      buffer.write('; "$label"');
    buffer.write(')');
    return buffer.toString();
  }

  /// Returns a string representation of this node and its descendants.
  String toStringDeep([String prefixLineOne = '', String prefixOtherLines = '']) {
    String result = '$prefixLineOne$this\n';
    if (_children != null && _children.isNotEmpty) {
      for (int index = 0; index < _children.length - 1; index += 1) {
        SemanticsNode child = _children[index];
        result += '${child.toStringDeep("$prefixOtherLines \u251C", "$prefixOtherLines \u2502")}';
      }
      result += '${_children.last.toStringDeep("$prefixOtherLines \u2514", "$prefixOtherLines  ")}';
    }
    return result;
  }
}

/// Signature for functions that receive updates about render tree semantics.
typedef void SemanticsListener(List<mojom.SemanticsNode> nodes);

/// Owns [SemanticsNode] objects and notifies listeners of changes to the
/// render tree semantics.
///
/// To listen for semantic updates, call [PipelineOwner.addSemanticsListener],
/// which will create a [SemanticsOwner] if necessary.
class SemanticsOwner {
  /// Creates a [SemanticsOwner].
  ///
  /// The `onLastListenerRemoved` argument must not be null and will be called
  /// when the last listener is removed from this object.
  SemanticsOwner({
    @required SemanticsListener initialListener,
    @required VoidCallback onLastListenerRemoved
  }) : _onLastListenerRemoved = onLastListenerRemoved {
    assert(_onLastListenerRemoved != null);
    addListener(initialListener);
  }

  final VoidCallback _onLastListenerRemoved;

  final List<SemanticsNode> _dirtyNodes = <SemanticsNode>[];
  final Map<int, SemanticsNode> _nodes = <int, SemanticsNode>{};
  final Set<SemanticsNode> _detachedNodes = new Set<SemanticsNode>();

  final List<SemanticsListener> _listeners = <SemanticsListener>[];

  /// Releases any resources retained by this object.
  ///
  /// Requires that there are no listeners registered with [addListener].
  void dispose() {
    assert(_listeners.isEmpty);
    _dirtyNodes.clear();
    _nodes.clear();
    _detachedNodes.clear();
  }

  /// Add a consumer of semantic data.
  ///
  /// After the [PipelineOwner] updates the semantic data for a given frame, it
  /// calls [sendSemanticsTree], which uploads the data to each listener
  /// registered with this function.
  ///
  /// Listeners can be removed with [removeListener].
  void addListener(SemanticsListener listener) {
    _listeners.add(listener);
  }

  /// Removes a consumer of semantic data.
  ///
  /// Listeners can be added with [addListener].
  void removeListener(SemanticsListener listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty)
      _onLastListenerRemoved();
  }

  /// Uploads the semantics tree to the listeners registered with [addListener].
  void sendSemanticsTree() {
    assert(_listeners.isNotEmpty);
    for (SemanticsNode oldNode in _detachedNodes) {
      // The other side will have forgotten this node if we even send
      // it again, so make sure to mark it dirty so that it'll get
      // sent if it is resurrected.
      oldNode._dirty = true;
    }
    _detachedNodes.clear();
    if (_dirtyNodes.isEmpty)
      return;
    _dirtyNodes.sort((SemanticsNode a, SemanticsNode b) => a.depth - b.depth);
    for (int index = 0; index < _dirtyNodes.length; index += 1) {
      // we mutate the list as we walk it here, which is why we use an index instead of an iterator
      SemanticsNode node = _dirtyNodes[index];
      assert(node._dirty);
      assert(node.parent == null || !node.parent._shouldMergeAllDescendantsIntoThisNode || node._inheritedMergeAllDescendantsIntoThisNode);
      if (node._shouldMergeAllDescendantsIntoThisNode) {
        assert(node.mergeAllDescendantsIntoThisNode || node.parent != null);
        if (node.mergeAllDescendantsIntoThisNode ||
            node.parent != null && node.parent._shouldMergeAllDescendantsIntoThisNode) {
          // if we're merged into our parent, make sure our parent is added to the list
          if (node.parent != null && node.parent._shouldMergeAllDescendantsIntoThisNode)
            node.parent._markDirty(); // this can add the node to the dirty list
          // make sure all the descendants are also marked, so that if one gets marked dirty later we know to walk up then too
          if (node._children != null) {
            for (SemanticsNode child in node._children)
              child._inheritedMergeAllDescendantsIntoThisNode = true; // this can add the node to the dirty list
          }
        } else {
          // we previously were being merged but aren't any more
          // update our bits and all our descendants'
          assert(node._inheritedMergeAllDescendantsIntoThisNode);
          assert(!node.mergeAllDescendantsIntoThisNode);
          assert(node.parent == null || !node.parent._shouldMergeAllDescendantsIntoThisNode);
          node._inheritedMergeAllDescendantsIntoThisNode = false;
          if (node._children != null) {
            for (SemanticsNode child in node._children)
              child._inheritedMergeAllDescendantsIntoThisNode = false; // this can add the node to the dirty list
          }
        }
      }
      assert(_dirtyNodes[index] == node); // make sure nothing went in front of us in the list
    }
    _dirtyNodes.sort((SemanticsNode a, SemanticsNode b) => a.depth - b.depth);
    List<mojom.SemanticsNode> updatedNodes = <mojom.SemanticsNode>[];
    for (SemanticsNode node in _dirtyNodes) {
      assert(node.parent?._dirty != true); // could be null (no parent) or false (not dirty)
      // The _serialize() method marks the node as not dirty, and
      // recurses through the tree to do a deep serialization of all
      // contiguous dirty nodes. This means that when we return here,
      // it's quite possible that subsequent nodes are no longer
      // dirty. We skip these here.
      // We also skip any nodes that were reset and subsequently
      // dropped entirely (RenderObject.markNeedsSemanticsUpdate()
      // calls reset() on its SemanticsNode if onlyChanges isn't set,
      // which happens e.g. when the node is no longer contributing
      // semantics).
      if (node._dirty && node.attached)
        updatedNodes.add(node._serialize());
    }
    for (SemanticsListener listener in new List<SemanticsListener>.from(_listeners))
      listener(updatedNodes);
    _dirtyNodes.clear();
  }

  SemanticActionHandler _getSemanticActionHandlerForId(int id, { @required SemanticAction action }) {
    assert(action != null);
    SemanticsNode result = _nodes[id];
    if (result != null && result._shouldMergeAllDescendantsIntoThisNode && !result._hasAction(action)) {
      result._visitDescendants((SemanticsNode node) {
        if (node._actionHandler != null && node._hasAction(action)) {
          result = node;
          return false; // found node, abort walk
        }
        return true; // continue walk
      });
    }
    if (result == null || !result._hasAction(action))
      return null;
    return result._actionHandler;
  }

  /// Asks the [SemanticsNode] with the given id to perform the given action.
  ///
  /// If the [SemanticsNode] has not indicated that it can perform the action,
  /// this function does nothing.
  void performAction(int id, SemanticAction action) {
    SemanticActionHandler handler = _getSemanticActionHandlerForId(id, action: action);
    handler?.performAction(action);
  }
}
