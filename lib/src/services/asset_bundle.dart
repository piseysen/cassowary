// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:sky' as sky;
import 'dart:sky.internals' as internals;
import 'dart:typed_data';

import 'package:mojo/core.dart' as core;
import 'package:mojo_services/mojo/asset_bundle/asset_bundle.mojom.dart';
import 'package:sky/src/services/fetch.dart';
import 'package:sky/src/services/image_cache.dart';
import 'package:sky/src/services/image_resource.dart';
import 'package:sky/src/services/shell.dart';

abstract class AssetBundle {
  void close();
  ImageResource loadImage(String key);
  Future<String> loadString(String key);
  Future<core.MojoDataPipeConsumer> load(String key);
}

class NetworkAssetBundle extends AssetBundle {
  NetworkAssetBundle(Uri baseUrl) : _baseUrl = baseUrl;

  final Uri _baseUrl;

  void close() { }

  String _urlFromKey(String key) => _baseUrl.resolve(key).toString();

  Future<core.MojoDataPipeConsumer> load(String key) async {
    return (await fetchUrl(_urlFromKey(key))).body;
  }

  ImageResource loadImage(String key) => imageCache.load(_urlFromKey(key));

  Future<String> loadString(String key) => fetchString(_urlFromKey(key));
}

Future _fetchAndUnpackBundle(String relativeUrl, AssetBundleProxy bundle) async {
  core.MojoDataPipeConsumer bundleData = (await fetchUrl(relativeUrl)).body;
  AssetUnpackerProxy unpacker = new AssetUnpackerProxy.unbound();
  shell.requestService("mojo:asset_bundle", unpacker);
  unpacker.ptr.unpackZipStream(bundleData, bundle);
  unpacker.close();
}

class MojoAssetBundle extends AssetBundle {
  MojoAssetBundle(AssetBundleProxy this._bundle);

  factory MojoAssetBundle.fromNetwork(String relativeUrl) {
    AssetBundleProxy bundle = new AssetBundleProxy.unbound();
    _fetchAndUnpackBundle(relativeUrl, bundle);
    return new MojoAssetBundle(bundle);
  }

  AssetBundleProxy _bundle;
  Map<String, ImageResource> _imageCache = new Map<String, ImageResource>();
  Map<String, Future<String>> _stringCache = new Map<String, Future<String>>();

  void close() {
    _bundle.close();
    _bundle = null;
    _imageCache = null;
  }

  ImageResource loadImage(String key) {
    return _imageCache.putIfAbsent(key, () {
      Completer<sky.Image> completer = new Completer<sky.Image>();
      load(key).then((assetData) {
        new sky.ImageDecoder(completer.complete)
               ..initWithConsumer(assetData.handle.h);
      });
      return new ImageResource(completer.future);
    });
  }

  Future<String> _fetchString(String key) async {
    core.MojoDataPipeConsumer pipe = await load(key);
    ByteData data = await core.DataPipeDrainer.drainHandle(pipe);
    return new String.fromCharCodes(new Uint8List.view(data.buffer));
  }

  Future<core.MojoDataPipeConsumer> load(String key) async {
    return (await _bundle.ptr.getAsStream(key)).assetData;
  }

  Future<String> loadString(String key) {
    return _stringCache.putIfAbsent(key, () => _fetchString(key));
  }
}

AssetBundle _initRootBundle() {
  try {
    AssetBundleProxy bundle = new AssetBundleProxy.fromHandle(
        new core.MojoHandle(internals.takeRootBundleHandle()));
    return new MojoAssetBundle(bundle);
  } catch (e) {
    return null;
  }
}

final AssetBundle rootBundle = _initRootBundle();
