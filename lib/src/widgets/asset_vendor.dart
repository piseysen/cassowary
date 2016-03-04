// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui show Image;

import 'package:flutter/services.dart';
import 'package:mojo/core.dart' as core;

import 'media_query.dart';
import 'basic.dart';
import 'framework.dart';

// Base class for asset resolvers.
abstract class _AssetResolver {
  // Return a resolved asset key for the asset named [name].
  Future<String> resolve(String name);
}

// Asset bundle capable of producing assets via the resolution logic of an
// asset resolver.
//
// Wraps an underlying [AssetBundle] and forwards calls after resolving the
// asset key.
class _ResolvingAssetBundle extends CachingAssetBundle {

  _ResolvingAssetBundle({ this.bundle, this.resolver });
  final AssetBundle bundle;
  final _AssetResolver resolver;

  final Map<String, String> keyCache = <String, String>{};

  Future<core.MojoDataPipeConsumer> load(String key) async {
    if (!keyCache.containsKey(key))
      keyCache[key] = await resolver.resolve(key);
    return await bundle.load(keyCache[key]);
  }
}

/// Abstraction for reading images out of a Mojo data pipe.
///
/// Useful for mocking purposes in unit tests.
typedef Future<ui.Image> ImageDecoder(core.MojoDataPipeConsumer pipe);

// Asset bundle that understands how specific asset keys represent image scale.
class _ResolutionAwareAssetBundle extends _ResolvingAssetBundle {
  _ResolutionAwareAssetBundle({
    AssetBundle bundle,
    _ResolutionAwareAssetResolver resolver,
    ImageDecoder imageDecoder
  }) : _imageDecoder = imageDecoder,
  super(
    bundle: bundle,
    resolver: resolver
  );

  _ResolutionAwareAssetResolver get resolver => super.resolver;

  final ImageDecoder _imageDecoder;

  Future<ImageInfo> fetchImage(String key) async {
    core.MojoDataPipeConsumer pipe = await load(key);
    // At this point the key should be in our key cache, and the image
    // resource should be in our image cache
    double scale = resolver.getScale(keyCache[key]);
    return new ImageInfo(
      image: await _imageDecoder(pipe),
      scale: scale
    );
  }
}

// Base class for resolvers that use the asset manifest to retrieve a list
// of asset variants to choose from.
abstract class _VariantAssetResolver extends _AssetResolver {
  _VariantAssetResolver({ this.bundle });
  final AssetBundle bundle;
  // TODO(kgiesing): Ideally, this cache would be on an object with the same
  // lifetime as the asset bundle it wraps. However, that won't matter until we
  // need to change AssetVendors frequently; as of this writing we only have
  // one.
  Map<String, List<String>> _assetManifest;
  Future _initializer;

  Future _loadManifest() async {
    String json = await bundle.loadString("AssetManifest.json");
    _assetManifest = JSON.decode(json);
  }

  Future<String> resolve(String name) async {
    _initializer ??= _loadManifest();
    await _initializer;
    // If there's no asset manifest, just return the main asset
    if (_assetManifest == null)
      return name;
    // Allow references directly to variants: if the supplied name is not a
    // key, just return it
    List<String> variants = _assetManifest[name];
    if (variants == null)
      return name;
    else
      return chooseVariant(name, variants);
  }

  String chooseVariant(String main, List<String> variants);
}

// Asset resolver that understands how to determine the best match for the
// current device pixel ratio
class _ResolutionAwareAssetResolver extends _VariantAssetResolver {
  _ResolutionAwareAssetResolver({ AssetBundle bundle, this.devicePixelRatio })
    : super(bundle: bundle);

  final double devicePixelRatio;

  // We assume the main asset is designed for a device pixel ratio of 1.0
  static const double _naturalResolution = 1.0;
  static final RegExp _extractRatioRegExp = new RegExp(r"/?(\d+(\.\d*)?)x/");

  double getScale(String key) {
    Match match = _extractRatioRegExp.firstMatch(key);
    if (match != null && match.groupCount > 0)
      return double.parse(match.group(1));
    return 1.0;
  }

  // Return the value for the key in a [SplayTreeMap] nearest the provided key.
  String _findNearest(SplayTreeMap<double, String> candidates, double value) {
    if (candidates.containsKey(value))
      return candidates[value];
    double lower = candidates.lastKeyBefore(value);
    double upper = candidates.firstKeyAfter(value);
    if (lower == null)
      return candidates[upper];
    if (upper == null)
      return candidates[lower];
    if (value > (lower + upper) / 2)
      return candidates[upper];
    else
      return candidates[lower];
  }

  String chooseVariant(String main, List<String> candidates) {
    SplayTreeMap<double, String> mapping = new SplayTreeMap<double, String>();
    for (String candidate in candidates)
      mapping[getScale(candidate)] = candidate;
    mapping[_naturalResolution] = main;
    return _findNearest(mapping, devicePixelRatio);
  }
}

/// Establishes an asset resolution strategy for its descendants.
///
/// Given a main asset and a set of variants, AssetVendor chooses the most
/// appropriate asset for the current context. The current asset resolution
/// strategy knows how to find the asset most closely matching the current
/// device pixel ratio - see [MediaQuery].
///
/// Main assets are presumed to match a nominal pixel ratio of 1.0. To specify
/// assets targeting different pixel ratios, place the variant assets in
/// the application bundle under subdirectories named in the form "Nx", where
/// N is the nominal device pixel ratio for that asset.
///
/// For example, suppose an application wants to use an icon named
/// "heart.png". This icon has representations at 1.0 (the main icon), as well
/// as 1.5 and 2.0 pixel ratios (variants). The asset bundle should then contain
/// the following assets:
///
/// ```
/// heart.png
/// 1.5x/heart.png
/// 2.0x/heart.png
/// ```
///
/// On a device with a 1.0 device pixel ratio, the image chosen would be
/// heart.png; on a device with a 1.3 device pixel ratio, the image chosen
/// would be 1.5x/heart.png.
///
/// The directory level of the asset does not matter as long as the variants are
/// at the equivalent level; that is, the following is also a valid bundle
/// structure:
///
/// ```
/// icons/heart.png
/// icons/1.5x/heart.png
/// icons/2.0x/heart.png
/// ```
class AssetVendor extends StatefulComponent {
  AssetVendor({
    Key key,
    this.bundle,
    this.devicePixelRatio,
    this.child,
    this.imageDecoder: decodeImageFromDataPipe
  }) : super(key: key);

  final AssetBundle bundle;
  final double devicePixelRatio;
  final Widget child;
  final ImageDecoder imageDecoder;

  _AssetVendorState createState() => new _AssetVendorState();

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('bundle: $bundle');
    if (devicePixelRatio != null)
      description.add('devicePixelRatio: $devicePixelRatio');
  }
}

class _AssetVendorState extends State<AssetVendor> {

  _ResolvingAssetBundle _bundle;

  void _initBundle() {
    _bundle = new _ResolutionAwareAssetBundle(
      bundle: config.bundle,
      imageDecoder: config.imageDecoder,
      resolver: new _ResolutionAwareAssetResolver(
        bundle: config.bundle,
        devicePixelRatio: config.devicePixelRatio
      )
    );
  }

  void initState() {
    super.initState();
    _initBundle();
  }

  void didUpdateConfig(AssetVendor oldConfig) {
    if (config.bundle != oldConfig.bundle ||
        config.devicePixelRatio != oldConfig.devicePixelRatio) {
      _initBundle();
    }
  }

  Widget build(BuildContext context) {
    return new DefaultAssetBundle(bundle: _bundle, child: config.child);
  }

  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('bundle: $_bundle');
  }
}
