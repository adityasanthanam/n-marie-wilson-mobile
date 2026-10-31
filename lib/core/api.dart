import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

SupabaseClient get supa => Supabase.instance.client;

/// HTTP calls to the web app. Filing and AI helpers use the same open routes the
/// website uses (/api/submit-grievance, /api/intake, /api/chat); news and tracking
/// go through the key-gated public gateway.
class Api {
  Api({http.Client? client}) : _http = client ?? http.Client();
  static final instance = Api();
  final http.Client _http;

  Uri _site(String path, [Map<String, String>? q]) => Uri.parse('${Config.siteUrl}$path').replace(queryParameters: q);
  Uri _gw(String path, [Map<String, String>? q]) => Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);

  Map<String, String> get _gwHeaders => {'X-API-Key': Config.citizenApiKey, 'Accept': 'application/json'};

  Map<String, String> _bearer() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  dynamic _decode(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (r.statusCode >= 400) {
      final msg = body is Map && body['error'] != null ? '${body['error']}' : 'Request failed (${r.statusCode})';
      throw ApiException(r.statusCode, msg);
    }
    return body;
  }

  // ---- Gateway (citizen scope) ----

  Future<List<Map<String, dynamic>>> news({int limit = 50, int offset = 0}) async {
    final r = await _http.get(_gw('/news', {'limit': '$limit', 'offset': '$offset'}), headers: _gwHeaders);
    return List<Map<String, dynamic>>.from(_decode(r)['data'] as List);
  }

  Future<Map<String, dynamic>?> track(String ref) async {
    final r = await _http.get(_gw('/track/${Uri.encodeComponent(ref.trim().toUpperCase())}'), headers: _gwHeaders);
    if (r.statusCode == 404) return null;
    return Map<String, dynamic>.from(_decode(r)['data'] as Map);
  }

  // ---- Web routes ----

  /// Same multipart request as the web IntakeDesk. Returns the reference code.
  Future<String> submitGrievance(Map<String, String> fields, List<File> files) async {
    final req = http.MultipartRequest('POST', _site('/api/submit-grievance'))
      ..headers.addAll(_bearer())
      ..fields.addAll(fields);
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath('photos', f.path,
          contentType: MediaType.parse(lookupMimeType(f.path) ?? 'application/octet-stream')));
    }
    final r = await http.Response.fromStream(await _http.send(req));
    final body = _decode(r);
    return '${body['reference_code']}';
  }

  /// AI form-fill: returns `{reply, ready, form}`.
  Future<Map<String, dynamic>> intake(List<Map<String, String>> messages, Map<String, String?> form, String lang) async {
    final r = await _http.post(_site('/api/intake'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages, 'form': form, 'lang': lang}));
    return Map<String, dynamic>.from(_decode(r) as Map);
  }

  /// Assistant chat. Streams text deltas from the SSE response.
  Stream<String> chat(List<Map<String, String>> messages, String lang, String sessionId) async* {
    final req = http.Request('POST', _site('/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'messages': messages, 'lang': lang, 'session_id': sessionId});
    final res = await _http.send(req);
    if (res.statusCode >= 400) {
      final body = await res.stream.bytesToString();
      String err = 'ai_error';
      try {
        err = '${jsonDecode(body)['error']}';
      } catch (_) {}
      throw ApiException(res.statusCode, err);
    }
    final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      try {
        final delta = jsonDecode(data)['choices']?[0]?['delta']?['content'];
        if (delta is String && delta.isNotEmpty) yield delta;
      } catch (_) {}
    }
  }

  // ---- Staff endpoints (/api/public/v1/staff/*), authorised by the staff member's own sign-in ----

  /// GET when [body] is null, POST otherwise. Unwraps `{data}`; a `{ok: false, error}` result throws.
  Future<dynamic> staff(String path, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = _gw('/staff/$path', query);
    final headers = {..._bearer(), 'Accept': 'application/json'};
    final r = body == null
        ? await _http.get(uri, headers: headers)
        : await _http.post(uri, headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode(body));
    final data = (_decode(r) as Map)['data'];
    if (data is Map && data['ok'] == false) throw ApiException(400, '${data['error'] ?? 'Request failed'}');
    return data;
  }

  /// Records a request for an admin to reset the password; always succeeds.
  Future<void> forgotPassword(String email) async => _decode(await _http.post(_gw('/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email.trim()})));

  /// Speech-to-text for call recordings (web: /api/staff-transcribe, streamed SSE).
  Future<String> transcribe(File file) async {
    final req = http.MultipartRequest('POST', _site('/api/staff-transcribe'))
      ..headers.addAll(_bearer())
      ..files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: MediaType.parse(lookupMimeType(file.path) ?? 'audio/mpeg')));
    final res = await _http.send(req);
    if (res.statusCode >= 400) _decode(await http.Response.fromStream(res));
    final buf = StringBuffer();
    String? done;
    final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      final e = jsonDecode(data);
      switch (e['type']) {
        case 'transcript.text.delta':
          buf.write(e['delta'] ?? '');
        case 'transcript.text.done':
          done = '${e['text'] ?? ''}';
        case 'error':
          throw ApiException(502, '${e['error']?['message'] ?? 'Transcription failed.'}');
      }
    }
    final text = (done ?? buf.toString()).trim();
    if (text.isEmpty) throw ApiException(422, 'No speech was found in the recording.');
    if (text.length > 10000) throw ApiException(413, 'The transcript is too long. Use a shorter recording.');
    return text;
  }
}
