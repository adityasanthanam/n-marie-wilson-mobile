import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Per-install chat session id (web: localStorage mw_chat_session_id).
Future<String> chatSessionId() async {
  try {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('mw_chat_session_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('mw_chat_session_id', id);
    }
    return id;
  } catch (_) {
    return 'app-${DateTime.now().millisecondsSinceEpoch}';
  }
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _messages = <Map<String, String>>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<String>? _sub;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text.trim()});
      _busy = true;
    });
    final history = List<Map<String, String>>.from(_messages);
    setState(() => _messages.add({'role': 'assistant', 'content': ''}));
    final sid = await chatSessionId();
    final buf = StringBuffer();
    _sub = Api.instance.chat(history, Lang.instance.code, sid).listen(
      (delta) {
        buf.write(delta);
        setState(() => _messages.last = {'role': 'assistant', 'content': buf.toString()});
        _toBottom();
      },
      onError: (Object e) {
        final status = e is ApiException ? e.status : 0;
        setState(() {
          _messages.last = {
            'role': 'assistant',
            'content': status == 429 ? t('chat.errorRate') : status == 402 ? t('chat.errorCredit') : t('chat.errorGeneric'),
          };
          _busy = false;
        });
      },
      onDone: () => setState(() => _busy = false),
    );
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  void _handoff() {
    final last = _messages.where((m) => (m['content'] ?? '').isNotEmpty).toList();
    context.go('/file', extra: last.length > 12 ? last.sublist(last.length - 12) : last);
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('chat.title')),
          Row(children: [
            const Icon(Icons.circle, size: 8, color: Brand.online),
            const SizedBox(width: 4),
            Flexible(child: Text(t('chat.online'), style: const TextStyle(fontSize: 11, color: Brand.muted), overflow: TextOverflow.ellipsis)),
          ]),
        ]),
        actions: const [LangToggle()],
      ),
      body: SafeArea(
        child: MaxWidth(
          width: 760,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                      onPressed: _handoff, icon: const Icon(Icons.edit_note), label: Text(L('File a grievance', 'புகார் அளிக்க'))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => context.go('/track'), icon: const Icon(Icons.search), label: Text(L('Track grievance', 'புகாரைக் கண்காணி'))),
                ),
              ]),
            ),
            Expanded(
              child: ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                _bubble('assistant', t('chat.greet')),
                if (_messages.isEmpty)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final q in ['chat.quick1', 'chat.quick2', 'chat.quick3']) ActionChip(label: Text(t(q)), onPressed: () => _send(t(q))),
                  ]),
                for (final m in _messages)
                  _bubble(m['role']!, m['content']!.isEmpty && _busy ? t('chat.thinking') : m['content']!),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(hintText: t('chat.placeholder')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                    tooltip: t('chat.send'), onPressed: _busy ? null : () => _send(_input.text), icon: const Icon(Icons.send)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bubble(String role, String text) {
    final mine = role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(color: mine ? Brand.red : const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(14)),
        child: mine
            ? Text(text, style: const TextStyle(color: Colors.white))
            : MarkdownBody(data: text, onTapLink: (_, href, _) => href == null ? null : openUrl(Uri.parse(href))),
      ),
    );
  }
}
