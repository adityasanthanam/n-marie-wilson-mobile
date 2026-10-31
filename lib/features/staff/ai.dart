import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

String _errorText(Object e) => e is ApiException ? e.message : 'Network error. Check your connection and try again.';

/// Admin AI assistant (AdminAssistant.tsx): chat over today's open grievances.
class StaffAssistantScreen extends StatefulWidget {
  const StaffAssistantScreen({super.key});
  @override
  State<StaffAssistantScreen> createState() => _StaffAssistantScreenState();
}

class _StaffAssistantScreenState extends State<StaffAssistantScreen> {
  static const _suggestions = ['What are the top grievances today?', "Any women's safety issues open?", 'Summarise critical cases by area'];
  final _messages = <Map<String, String>>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _messages.add({'role': 'user', 'content': q.length > 4000 ? q.substring(0, 4000) : q});
      _input.clear();
      _busy = true;
      _error = null;
    });
    _toEnd();
    try {
      final recent = _messages.length > 12 ? _messages.sublist(_messages.length - 12) : _messages;
      final r = await Api.instance.staff('ai/assistant', body: {'messages': recent}) as Map;
      _messages.add({'role': 'assistant', 'content': '${r['answer'] ?? ''}'});
    } catch (e) {
      _error = _errorText(e);
    }
    if (mounted) setState(() => _busy = false);
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI assistant')),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: [
                MaxWidth(
                  width: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_messages.isEmpty) ...[
                        const Text('Ask about the open grievances you can see.', style: TextStyle(color: Brand.muted)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final s in _suggestions) _Suggestion(s, onPressed: () => _send(s))],
                        ),
                      ],
                      for (final m in _messages) _bubble(m),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator.adaptive()),
                        ),
                      if (_error != null) Notice(_error!),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MaxWidth(
            width: 760,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(hintText: 'Ask a question…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _busy ? null : () => _send(_input.text), icon: const Icon(Icons.send), tooltip: 'Send'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bubble(Map<String, String> m) {
    final user = m['role'] == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 620),
        decoration: BoxDecoration(color: user ? const Color(0xFFFEF2F2) : const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(10)),
        child: user ? SelectableText(m['content']!) : MarkdownBody(data: m['content']!, selectable: true),
      ),
    );
  }
}

/// Example question; wraps onto several lines on narrow phones instead of overflowing.
class _Suggestion extends StatelessWidget {
  const _Suggestion(this.text, {required this.onPressed});
  final String text;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 36),
      textStyle: const TextStyle(fontSize: 12),
    ),
    onPressed: onPressed,
    child: Text(text, softWrap: true),
  );
}

typedef AnalystTable = ({String title, List<String> columns, List<List<String>> rows});

/// TeamAnalyst.tsx: asks a question over data the dashboard builds on the device.
class AnalystCard extends StatefulWidget {
  const AnalystCard({super.key, required this.buildData, this.mode = 'team'});
  final Future<String> Function() buildData;
  final String mode;
  @override
  State<AnalystCard> createState() => _AnalystCardState();
}

class _AnalystCardState extends State<AnalystCard> {
  final _q = TextEditingController();
  bool _busy = false;
  String? _error, _answer;
  AnalystTable? _table;

  bool get _team => widget.mode == 'team';
  List<String> get _examples => _team
      ? const ['Who did not work today?', 'Who has the most untouched tickets?', 'How many tickets did each person close this period?']
      : const [
          'Which ward has the highest number of complaints?',
          'Which department takes the longest to resolve issues?',
          'Which areas have recurring infrastructure problems?',
          'எந்த வார்டில் அதிக புகார்கள் உள்ளன?',
        ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run(String question) async {
    if (question.trim().isEmpty || _busy) return;
    setState(() {
      _q.text = question;
      _busy = true;
      _error = _answer = null;
      _table = null;
    });
    try {
      final r = await Api.instance.staff('ai/analyst', body: {'question': question.trim(), 'data': await widget.buildData(), 'mode': widget.mode}) as Map;
      _answer = '${r['answer'] ?? ''}';
      final t = r['table'];
      if (t is Map) {
        _table = (
          title: '${t['title'] ?? ''}',
          columns: [for (final c in t['columns'] as List? ?? const []) '$c'],
          rows: [
            for (final row in t['rows'] as List? ?? const []) [for (final c in row as List) '${c ?? ''}'],
          ],
        );
      }
    } catch (e) {
      _error = e is ApiException ? e.message : 'Analysis failed';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Brand.red),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_team ? 'Ask about team performance' : 'Ask about grievances', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  maxLength: 1000,
                  enabled: !_busy,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _run,
                  decoration: InputDecoration(counterText: '', hintText: _team ? 'e.g. Who did not work today?' : 'Ask in English or Tamil…'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _run(_q.text),
                child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ask'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in _examples)
                _Suggestion(x, onPressed: _busy ? null : () => _run(x)),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 8), Notice(_error!)],
          if (_answer != null) ...[const SizedBox(height: 10), SelectableText(_answer!)],
          if (_table case final t? when t.rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${t.title} · ${t.rows.length} rows', style: const TextStyle(fontSize: 12, color: Brand.muted)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    columns: [for (final c in t.columns) DataColumn(label: Text(c))],
                    rows: [
                      for (final r in t.rows) DataRow(cells: [for (var i = 0; i < t.columns.length; i++) DataCell(Text(i < r.length ? r[i] : ''))]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
