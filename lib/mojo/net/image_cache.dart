// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:sky' as sky;

import 'package:mojo/mojo/url_response.mojom.dart';
import 'package:sky/mojo/image_resource.dart';
import 'package:sky/mojo/net/fetch.dart';

final HashMap<String, ImageResource> _cache = new Map<String, ImageResource>();

ImageResource load(String url) {
  return _cache.putIfAbsent(url, () {
    Completer<sky.Image> completer = new Completer<sky.Image>();
    fetchUrl(url).then((UrlResponse response) {
      if (response.statusCode >= 400) {
        print("Failed (${response.statusCode}) to load image ${url}");
        completer.complete(null);
      } else {
        new sky.ImageDecoder(response.body.handle.h, completer.complete);
      }
    });
    return new ImageResource(completer.future);
  });
}
