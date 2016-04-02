// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui show window;

import 'package:flutter/services.dart';
import 'package:mojo/bindings.dart' as mojo_bindings;
import 'package:mojo/core.dart' as mojo_core;
import 'package:sky_services/pointer/pointer.mojom.dart';

import 'arena.dart';
import 'converter.dart';
import 'events.dart';
import 'hit_test.dart';
import 'pointer_router.dart';

/// A binding for the gesture subsystem.
abstract class Gesturer extends BindingBase implements HitTestTarget, HitTestable {

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    ui.window.onPointerPacket = _handlePointerPacket;
  }

  /// The singleton instance of this object.
  static Gesturer get instance => _instance;
  static Gesturer _instance;

  void _handlePointerPacket(ByteData serializedPacket) {
    final mojo_bindings.Message message = new mojo_bindings.Message(
      serializedPacket,
      <mojo_core.MojoHandle>[],
      serializedPacket.lengthInBytes,
      0
    );
    final PointerPacket packet = PointerPacket.deserialize(message);
    for (PointerEvent event in PointerEventConverter.expand(packet.pointers))
      _handlePointerEvent(event);
  }

  /// A router that routes all pointer events received from the engine.
  final PointerRouter pointerRouter = new PointerRouter();

  /// The gesture arenas used for disambiguating the meaning of sequences of
  /// pointer events.
  final GestureArenaManager gestureArena = new GestureArenaManager();

  /// State for all pointers which are currently down.
  ///
  /// The state of hovering pointers is not tracked because that would require
  /// hit-testing on every frame.
  Map<int, HitTestResult> _hitTests = <int, HitTestResult>{};

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      assert(!_hitTests.containsKey(event.pointer));
      HitTestResult result = new HitTestResult();
      hitTest(result, event.position);
      _hitTests[event.pointer] = result;
    } else if (event is! PointerUpEvent) {
      assert(event.down == _hitTests.containsKey(event.pointer));
      if (!event.down)
        return; // we currently ignore add, remove, and hover move events
    }
    assert(_hitTests[event.pointer] != null);
    dispatchEvent(event, _hitTests[event.pointer]);
    if (event is PointerUpEvent) {
      assert(_hitTests.containsKey(event.pointer));
      _hitTests.remove(event.pointer);
    }
  }

  /// Determine which [HitTestTarget] objects are located at a given position.
  @override
  void hitTest(HitTestResult result, Point position) {
    result.add(new HitTestEntry(this));
  }

  /// Dispatch the given event to the path of the given hit test result
  void dispatchEvent(PointerEvent event, HitTestResult result) {
    assert(result != null);
    for (HitTestEntry entry in result.path) {
      try {
        entry.target.handleEvent(event, entry);
      } catch (exception, stack) {
        FlutterError.reportError(new FlutterErrorDetailsForPointerEventDispatcher(
          exception: exception,
          stack: stack,
          library: 'gesture library',
          context: 'while dispatching a pointer event',
          event: event,
          hitTestEntry: entry,
          informationCollector: (StringBuffer information) {
            information.writeln('Event:');
            information.writeln('  $event');
            information.writeln('Target:');
            information.write('  ${entry.target}');
          }
        ));
      }
    }
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    pointerRouter.route(event);
    if (event is PointerDownEvent) {
      gestureArena.close(event.pointer);
    } else if (event is PointerUpEvent) {
      gestureArena.sweep(event.pointer);
    }
  }
}

/// Variant of [FlutterErrorDetails] with extra fields for the gesture
/// library's binding's pointer event dispatcher ([Gesturer.dispatchEvent]).
///
/// See also [FlutterErrorDetailsForPointerRouter], which is also used by the
/// gesture library.
class FlutterErrorDetailsForPointerEventDispatcher extends FlutterErrorDetails {
  /// Creates a [FlutterErrorDetailsForPointerEventDispatcher] object with the given
  /// arguments setting the object's properties.
  ///
  /// The gesture library calls this constructor when catching an exception
  /// that will subsequently be reported using [FlutterError.onError].
  const FlutterErrorDetailsForPointerEventDispatcher({
    dynamic exception,
    StackTrace stack,
    String library,
    String context,
    this.event,
    this.hitTestEntry,
    FlutterInformationCollector informationCollector,
    bool silent
  }) : super(
    exception: exception,
    stack: stack,
    library: library,
    context: context,
    informationCollector: informationCollector,
    silent: silent
  );

  /// The pointer event that was being routed when the exception was raised.
  final PointerEvent event;

  /// The hit test result entry for the object whose handleEvent method threw
  /// the exception.
  /// 
  /// The target object itself is given by the [HitTestEntry.target] property of
  /// the hitTestEntry object.
  final HitTestEntry hitTestEntry;
}

