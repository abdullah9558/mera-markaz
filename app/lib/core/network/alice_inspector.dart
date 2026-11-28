import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alice/alice.dart';
import 'package:alice/core/alice_adapter.dart';
import 'package:alice/model/alice_configuration.dart';
import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_error.dart';
import 'package:alice/model/alice_http_request.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shared root navigator key used by both GoRouter and Alice Inspector.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AliceInspector {
  AliceInspector._();

  static Alice? _alice;
  static int _nextCallId = 1;

  static bool get enabled => !kReleaseMode;

  /// Initializes Alice and installs a global `HttpOverrides` wrapper in
  /// debug/profile builds so all `dart:io` HTTP calls (Pakistan Live, Feedback,
  /// Firebase AI / Gemini, etc.) appear automatically in the inspector.
  static void initialize() {
    if (!enabled || _alice != null) return;
    final alice = Alice(
      configuration: AliceConfiguration(
        navigatorKey: appNavigatorKey,
        showNotification: true,
        showInspectorOnShake: true,
      ),
    );
    final adapter = _DartIoAliceAdapter();
    alice.addAdapter(adapter);
    _alice = alice;

    final previous = HttpOverrides.current;
    HttpOverrides.global = _AliceHttpOverrides(previous, adapter);
  }

  static void showInspector() {
    _alice?.showInspector();
  }

  static int nextId() => _nextCallId++;
}

class _DartIoAliceAdapter with AliceAdapter {
  void startCall(AliceHttpCall call) {
    aliceCore.addCall(call);
  }

  void finishCall(int callId, AliceHttpResponse response) {
    aliceCore.addResponse(response, callId);
  }

  void failCall(int callId, Object error, StackTrace stackTrace) {
    aliceCore.addError(
      AliceHttpError()
        ..error = error.toString()
        ..stackTrace = stackTrace,
      callId,
    );
    aliceCore.addResponse(
      AliceHttpResponse()
        ..status = -1
        ..time = DateTime.now(),
      callId,
    );
  }
}

class _AliceHttpOverrides extends HttpOverrides {
  _AliceHttpOverrides(this._previous, this._adapter);

  final HttpOverrides? _previous;
  final _DartIoAliceAdapter _adapter;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = _previous != null
        ? _previous.createHttpClient(context)
        : super.createHttpClient(context);
    return _AliceHttpClient(inner, _adapter);
  }
}

class _AliceHttpClient implements HttpClient {
  _AliceHttpClient(this._inner, this._adapter);

  final HttpClient _inner;
  final _DartIoAliceAdapter _adapter;

  Future<HttpClientRequest> _wrap(
    Future<HttpClientRequest> future,
    String method,
    Uri uri,
  ) async {
    final request = await future;
    return _AliceHttpClientRequest(request, _adapter, method, uri);
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    final uri = Uri(scheme: 'http', host: host, port: port, path: path);
    return _wrap(_inner.open(method, host, port, path), method, uri);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _wrap(_inner.openUrl(method, url), method, url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(void Function(String line)? callback) => _inner.keyLog = callback;
}

class _AliceHttpClientRequest implements HttpClientRequest {
  _AliceHttpClientRequest(this._inner, this._adapter, this._method, this._uri);

  final HttpClientRequest _inner;
  final _DartIoAliceAdapter _adapter;
  final String _method;
  final Uri _uri;
  final List<int> _bodyBytes = <int>[];

  int? _callId;

  void _recordStart() {
    if (_callId != null) return;
    final id = AliceInspector.nextId();
    _callId = id;

    final headers = <String, String>{};
    _inner.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    final request = AliceHttpRequest()
      ..size = _bodyBytes.length
      ..time = DateTime.now()
      ..headers = headers
      ..contentType = _inner.headers.contentType?.toString() ?? ''
      ..cookies = List<Cookie>.from(_inner.cookies)
      ..queryParameters = Map<String, dynamic>.from(_uri.queryParameters)
      ..body = _decodeBody(_bodyBytes);

    final call = AliceHttpCall(id)
      ..client = 'HttpClient'
      ..loading = true
      ..secure = _uri.scheme == 'https'
      ..method = _method.toUpperCase()
      ..server = _uri.hasPort ? '${_uri.host}:${_uri.port}' : _uri.host
      ..endpoint = _uri.path.isEmpty ? '/' : _uri.path
      ..uri = _uri.toString()
      ..request = request
      ..response = AliceHttpResponse();

    _adapter.startCall(call);
  }

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    final controller = StreamController<List<int>>();
    stream.listen(
      (chunk) {
        _bodyBytes.addAll(chunk);
        controller.add(chunk);
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    return _inner.addStream(controller.stream);
  }

  @override
  void write(Object? object) {
    final text = '$object';
    _bodyBytes.addAll(encoding.encode(text));
    _inner.write(object);
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    final text = objects.join(separator);
    _bodyBytes.addAll(encoding.encode(text));
    _inner.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _bodyBytes.addAll(encoding.encode(String.fromCharCode(charCode)));
    _inner.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    final text = '$object\n';
    _bodyBytes.addAll(encoding.encode(text));
    _inner.writeln(object);
  }

  @override
  Future<HttpClientResponse> close() async {
    _recordStart();
    final id = _callId!;
    try {
      final response = await _inner.close();
      return _AliceHttpClientResponse(response, _adapter, id);
    } catch (error, stackTrace) {
      _adapter.failCall(id, error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    if (_callId != null) {
      _adapter.failCall(
        _callId!,
        exception ?? 'Request aborted',
        stackTrace ?? StackTrace.current,
      );
    }
    _inner.abort(exception, stackTrace);
  }

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  Future<void> flush() => _inner.flush();

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  String get method => _inner.method;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  Uri get uri => _inner.uri;
}

class _AliceHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _AliceHttpClientResponse(this._inner, this._adapter, this._callId);

  final HttpClientResponse _inner;
  final _DartIoAliceAdapter _adapter;
  final int _callId;
  final List<int> _responseBytes = <int>[];
  bool _recorded = false;

  void _recordComplete() {
    if (_recorded) return;
    _recorded = true;
    final headers = <String, String>{};
    _inner.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });
    _adapter.finishCall(
      _callId,
      AliceHttpResponse()
        ..status = _inner.statusCode
        ..size = _responseBytes.length
        ..time = DateTime.now()
        ..headers = headers
        ..body = _decodeBody(_responseBytes),
    );
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _inner.listen(
      (chunk) {
        _responseBytes.addAll(chunk);
        onData?.call(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_recorded) {
          _recorded = true;
          _adapter.failCall(_callId, error, stackTrace);
        }
        if (onError is void Function(Object, StackTrace)) {
          onError(error, stackTrace);
        } else if (onError is void Function(Object)) {
          onError(error);
        }
      },
      onDone: () {
        _recordComplete();
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  @override
  X509Certificate? get certificate => _inner.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  int get contentLength => _inner.contentLength;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  bool get isRedirect => _inner.isRedirect;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  String get reasonPhrase => _inner.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => _inner.redirect(method, url, followLoops);

  @override
  List<RedirectInfo> get redirects => _inner.redirects;

  @override
  int get statusCode => _inner.statusCode;
}

dynamic _decodeBody(List<int> bytes) {
  if (bytes.isEmpty) return '';
  try {
    final text = utf8.decode(bytes);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  } catch (_) {
    return '<binary ${bytes.length} bytes>';
  }
}
