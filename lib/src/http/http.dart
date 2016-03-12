// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'mojo_client.dart';
import 'response.dart';

/// Sends an HTTP HEAD request with the given headers to the given URL, which
/// can be a [Uri] or a [String].
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> head(dynamic url) {
  return _withClient/*<Response>*/((MojoClient client) => client.head(url));
}

/// Sends an HTTP GET request with the given headers to the given URL, which can
/// be a [Uri] or a [String].
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> get(dynamic url, { Map<String, String> headers }) {
  return _withClient/*<Response>*/((MojoClient client) => client.get(url, headers: headers));
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
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> post(dynamic url, { Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
  return _withClient/*<Response>*/((MojoClient client) {
    return client.post(url, headers: headers, body: body, encoding: encoding);
  });
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
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> put(dynamic url, { Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
  return _withClient/*<Response>*/((MojoClient client) {
    return client.put(url, headers: headers, body: body, encoding: encoding);
  });
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
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> patch(dynamic url, { Map<String, String> headers, dynamic body, Encoding encoding: UTF8 }) {
  return _withClient/*<Response>*/((MojoClient client) {
     return client.patch(url, headers: headers, body: body, encoding: encoding);
  });
}

/// Sends an HTTP DELETE request with the given headers to the given URL, which
/// can be a [Uri] or a [String].
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Response> delete(dynamic url, { Map<String, String> headers }) {
  return _withClient/*<Response>*/((MojoClient client) => client.delete(url, headers: headers));
}

/// Sends an HTTP GET request with the given headers to the given URL, which can
/// be a [Uri] or a [String], and returns a Future that completes to the body of
/// the response as a [String].
///
/// The Future will emit a [ClientException] if the response doesn't have a
/// success status code.
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<String> read(dynamic url, { Map<String, String> headers }) {
  return _withClient/*<String>*/((MojoClient client) => client.read(url, headers: headers));
}

/// Sends an HTTP GET request with the given headers to the given URL, which can
/// be a [Uri] or a [String], and returns a Future that completes to the body of
/// the response as a list of bytes.
///
/// The Future will emit a [ClientException] if the response doesn't have a
/// success status code.
///
/// This automatically initializes a new [MojoClient] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [MojoClient] for all of those requests.
Future<Uint8List> readBytes(dynamic url, { Map<String, String> headers }) {
  return _withClient/*<Uint8List>*/((MojoClient client) => client.readBytes(url, headers: headers));
}

Future/*<T>*/ _withClient/*<T>*/(Future/*<T>*/ fn(MojoClient client)) {
  return fn(new MojoClient());
}
