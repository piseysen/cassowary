// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';
import 'dart:async';

import 'package:sky_services/activity/activity.mojom.dart';

import 'binding.dart';

export 'package:sky_services/activity/activity.mojom.dart';

// Dart wrapper around Activity mojo service available in Flutter on Android.
//
// Most clients will want to use these methods instead of the activity service
// directly.

// The constants below are from
// http://developer.android.com/reference/android/content/Intent.html

/// Open a document into a new task rooted at the activity launched by
/// this Intent.
/// 
/// See Android's Intent.FLAG_ACTIVITY_NEW_DOCUMENT.
const int NEW_DOCUMENT = 0x00080000; // ignore: constant_identifier_names

/// Start a new task on this history stack.
///
/// See Android's Intent.FLAG_ACTIVITY_NEW_TASK.
const int NEW_TASK = 0x10000000; // ignore: constant_identifier_names

/// Create a new task and launch an activity into it.
///
/// See Android's Intent.FLAG_ACTIVITY_MULTIPLE_TASK.
const int MULTIPLE_TASK = 0x08000000; // ignore: constant_identifier_names

ActivityProxy _initActivityProxy() {
  ActivityProxy activity = new ActivityProxy.unbound();
  shell.connectToService("mojo:android", activity);
  return activity;
}

final ActivityProxy _activityProxy = _initActivityProxy();
final Activity activity = _activityProxy.ptr;

UserFeedbackProxy _initUserFeedbackProxy() {
  UserFeedbackProxy proxy = new UserFeedbackProxy.unbound();
  _activityProxy.ptr.getUserFeedback(proxy);
  return proxy;
}

final UserFeedbackProxy _userFeedbackProxy = _initUserFeedbackProxy();
final UserFeedback userFeedback = _userFeedbackProxy.ptr;

PathServiceProxy _initPathServiceProxy() {
  PathServiceProxy proxy = new PathServiceProxy.unbound();
  shell.connectToService(null, proxy);
  return proxy;
}

final PathServiceProxy _pathServiceProxy = _initPathServiceProxy();
final PathService pathService = _pathServiceProxy.ptr;

Color _cachedPrimaryColor;
String _cachedLabel;

/// Sets the TaskDescription for the current Activity.
/// The color, if provided, must be opaque.
void updateTaskDescription({ String label, Color color }) {
  assert(color == null || color.alpha == 0xFF);
  if (_cachedPrimaryColor == color && _cachedLabel == label)
    return;

  _cachedPrimaryColor = color;
  _cachedLabel = label;

  TaskDescription description = new TaskDescription()
    ..label = label
    ..primaryColor = color?.value ?? 0;

  _activityProxy.ptr.setTaskDescription(description);
}

Future<String> getAppDataDir() async => (await _pathServiceProxy.ptr.getAppDataDir()).path;
Future<String> getFilesDir() async => (await _pathServiceProxy.ptr.getFilesDir()).path;
Future<String> getCacheDir() async => (await _pathServiceProxy.ptr.getCacheDir()).path;
