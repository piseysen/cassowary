// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mojo_services/mojo/network_service.mojom.dart' as mojo;
import 'package:mojo_services/mojo/url_loader.mojom.dart' as mojo;
import 'package:mojo/core.dart' as mojo;
import 'package:mojo/mojo/url_request.mojom.dart' as mojo;
import 'package:mojo/mojo/url_response.mojom.dart' as mojo;
import 'package:mojo/mojo/http_header.mojom.dart' as mojo;

import 'response.dart';

/// A `mojo`-based HTTP client.
class MojoClient {

  /// Sends an HTTP HEAD request with the given headers to the given URL, which
  /// can be a [Uri] or a [String].
  Future<Response> head(dynamic url, { Map<String, String> headers }) {
    return _send("HEAD", url, headers);
  }

  /// Sends an HTTP GET request with the given headers to the given URL, which can
  /// be a [Uri] or a [String].
  Future<Response> get(dynamic url, { Map<String, String> headers }) {
    return _send("GET", url, headers);
  }

  /// Sends an HTTP POST request with the given headers and body to the given URL,
  /// which can be a [Uri] or a [String].
  ///
  /// [body] sets the body of the request. It can be a [String], a [List<int>] or
  /// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
  /// used as the body of the request. The content-type of the request will
  /// default to "text/plain".
  ///
  /// If [body] is a List, it's used as a list of bytes for the body of the
  /// request.
  ///
  /// If [body] is a Map, it's encoded as form fields using [encoding]. The
  /// content-type of the request will be set to
  /// `"application/x-www-form-urlencoded"`; this cannot be overridden.
  ///
  /// [encoding] defaults to [UTF8].
  Future<Response> post(dynamic url, { Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
    return _send("POST", url, headers, body, encoding);
  }

  /// Sends an HTTP PUT request with the given headers and body to the given URL,
  /// which can be a [Uri] or a [String].
  ///
  /// [body] sets the body of the request. It can be a [String], a [List<int>] or
  /// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
  /// used as the body of the request. The content-type of the request will
  /// default to "text/plain".
  ///
  /// If [body] is a List, it's used as a list of bytes for the body of the
  /// request.
  ///
  /// If [body] is a Map, it's encoded as form fields using [encoding]. The
  /// content-type of the request will be set to
  /// `"application/x-www-form-urlencoded"`; this cannot be overridden.
  ///
  /// [encoding] defaults to [UTF8].
  Future<Response> put(dynamic url, { Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
    return _send("PUT", url, headers, body, encoding);
  }

  /// Sends an HTTP PATCH request with the given headers and body to the given
  /// URL, which can be a [Uri] or a [String].
  ///
  /// [body] sets the body of the request. It can be a [String], a [List<int>] or
  /// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
  /// used as the body of the request. The content-type of the request will
  /// default to "text/plain".
  ///
  /// If [body] is a List, it's used as a list of bytes for the body of the
  /// request.
  ///
  /// If [body] is a Map, it's encoded as form fields using [encoding]. The
  /// content-type of the request will be set to
  /// `"application/x-www-form-urlencoded"`; this cannot be overridden.
  ///
  /// [encoding] defaults to [UTF8].
  Future<Response> patch(dynamic url, {Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
    return _send("PATCH", url, headers, body, encoding);
  }

  /// Sends an HTTP DELETE request with the given headers to the given URL, which
  /// can be a [Uri] or a [String].
  Future<Response> delete(dynamic url, { Map<String, String> headers }) {
    return _send("DELETE", url, headers);
  }

  /// Sends an HTTP GET request with the given headers to the given URL, which can
  /// be a [Uri] or a [String], and returns a Future that completes to the body of
  /// the response as a [String].
  ///
  /// The Future will emit a [ClientException] if the response doesn't have a
  /// success status code.
  Future<String> read(dynamic url, { Map<String, String> headers }) {
    return get(url, headers: headers).then((Response response) {
      _checkResponseSuccess(url, response);
      return response.body;
    });
  }

  /// Sends an HTTP GET request with the given headers to the given URL, which can
  /// be a [Uri] or a [String], and returns a Future that completes to the body of
  /// the response as a list of bytes.
  ///
  /// The Future will emit a [ClientException] if the response doesn't have a
  /// success status code.
  Future<Uint8List> readBytes(dynamic url, { Map<String, String> headers }) {
    return get(url, headers: headers).then((Response response) {
      _checkResponseSuccess(url, response);
      return response.bodyBytes;
    });
  }

  Future<Response> _send(String method, dynamic url, Map<String, String> headers, [dynamic body, Encoding encoding = UTF8]) async {
    mojo.UrlLoaderProxy loader = new mojo.UrlLoaderProxy.unbound();
    List<mojo.HttpHeader> mojoHeaders = <mojo.HttpHeader>[];
    headers?.forEach((String name, String value) {
      mojo.HttpHeader header = new mojo.HttpHeader()
        ..name = name
        ..value = value;
      mojoHeaders.add(header);
    });
    mojo.UrlRequest request = new mojo.UrlRequest()
      ..url = url.toString()
      ..headers = mojoHeaders
      ..method = method;
    if (body != null) {
      mojo.MojoDataPipe pipe = new mojo.MojoDataPipe();
      request.body = <mojo.MojoDataPipeConsumer>[pipe.consumer];
      Uint8List encodedBody = encoding.encode(body);
      ByteData data = new ByteData.view(encodedBody.buffer);
      mojo.DataPipeFiller.fillHandle(pipe.producer, data);
    }
    try {
      networkService.ptr.createUrlLoader(loader);
      mojo.UrlResponse response = (await loader.ptr.start(request)).response;
      ByteData data = await mojo.DataPipeDrainer.drainHandle(response.body);
      Uint8List bodyBytes = new Uint8List.view(data.buffer);
      return new Response(bodyBytes: bodyBytes, statusCode: response.statusCode);
    } catch (exception, stack) {
      FlutterError.reportError(new FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'networking HTTP library',
        context: 'while sending bytes to the Mojo network library',
        silent: true
      ));
      return new Response(statusCode: 500);
    } finally {
      loader.close();
    }
  }

  void _checkResponseSuccess(dynamic url, Response response) {
    if (response.statusCode < 400)
      return;
    throw new Exception("Request to $url failed with status ${response.statusCode}.");
  }

  static mojo.NetworkServiceProxy _initNetworkService() {
    mojo.NetworkServiceProxy proxy = new mojo.NetworkServiceProxy.unbound();
    shell.connectToService("mojo:authenticated_network_service", proxy);
    return proxy;
  }

  /// A handle to the [NetworkService] object used by [MojoClient].
  static final mojo.NetworkServiceProxy networkService = _initNetworkService();
}
