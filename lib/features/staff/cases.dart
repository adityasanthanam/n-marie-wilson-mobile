import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'case_detail.dart';
import 'data.dart';
import 'session.dart';
import 'staff_meta.dart';

enum Queue { all, unassigned, groups, me }

enum SortKey { newest, oldest, priority }

class CaseFilters {
  Set<String> statuses = {}, constituencies = {}, categories = {}, priorities = {}, departments = {};
  bool women = false, flooding = false, corruption = false, pendingPublic = false, repeat = false, contactCenter = false;
  int get count =>
      [statuses, constituencies, categories, priorities, departments].where((s) => s.isNotEmpty).length +
      [women, flooding, corruption, pendingPublic, repeat, contactCenter].where((b) => b).length;
  void clear() {
    for (final s in [statuses, constituencies, categories, priorities, departments]) {
      s.clear();
    }
    women = flooding = corruption = pendingPublic = repeat = contactCenter = false;
  }
}

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key, this.selectedId});
  final String? selectedId;
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final s = StaffSession.instance;
  List<DbRow>? _rows;
  Object? _error;
  Map<String, String> _groups = {};
  Set<String> _myGroups = {};
  List<Department> _departments = [];
  final _filters = CaseFilters();
  Queue _queue = Queue.all;
  SortKey _sort = SortKey.newest;
  String _q = '';
  String? _selected;
  int _shown = 50;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        StaffData.grievances(),
        StaffData.groupNames(),
        StaffData.myGroups(s.uid!),
        StaffData.departments().catchError((_) => <Department>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List<DbRow>).where(s.caps.canSeeRow).toList();
        _groups = results[1] as Map<String, String>;
        _myGroups = results[2] as Set<String>;
        _departments = results[3] as List<Department>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Map<String, int> get _personCounts {
    final m = <String, int>{};
    for (final g in _rows ?? const <DbRow>[]) {
      m.update(personKey(g), (v) => v + 1, ifAbsent: () => 1);
    }
    return m;
  }

  List<DbRow> _visible() {
    final f = _filters;
    final persons = _personCounts;
    final q = _q.trim().toLowerCase();
    final list = (_rows ?? const <DbRow>[]).where((g) {
      switch (_queue) {
        case Queue.unassigned:
          if (g['assigned_to'] != null) return false;
        case Queue.groups:
          if (!_myGroups.contains(g['assigned_group'])) return false;
        case Queue.me:
          if (g['assigned_to'] != s.uid) return false;
        case Queue.all:
      }
      if (f.statuses.isNotEmpty && !f.statuses.contains(g['status'])) return false;
      if (f.constituencies.isNotEmpty && !f.constituencies.contains(g['constituency'] ?? 'none')) return false;
      if (f.categories.isNotEmpty && !f.categories.contains(g['category'] ?? 'other')) return false;
      if (f.priorities.isNotEmpty && !f.priorities.contains(g['priority_level'] ?? 'low')) return false;
      if (f.departments.isNotEmpty && !f.departments.contains(g['department_id'])) return false;
      if (f.women && !isWomenSafety(g)) return false;
      if (f.flooding && g['flooding'] != true) return false;
      if (f.corruption && g['corruption_type'] == null) return false;
      if (f.pendingPublic && !(g['public_requested'] == true && g['public_approved'] != true)) return false;
      if (f.repeat && (persons[personKey(g)] ?? 0) <= 1) return false;
      if (f.contactCenter && g['source'] != 'contact_center') return false;
      if (q.isNotEmpty) {
        final hay = '${g['reference_code']} ${g['name']} ${g['contact']} ${g['area']} ${g['description']}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    int byDate(DbRow a, DbRow b) => '${b['created_at']}'.compareTo('${a['created_at']}');
    list.sort(switch (_sort) {
      SortKey.newest => byDate,
      SortKey.oldest => (a, b) => -byDate(a, b),
      SortKey.priority => (a, b) {
          final d = ((b['priority_score'] as num?) ?? -1).compareTo((a['priority_score'] as num?) ?? -1);
          return d != 0 ? d : byDate(a, b);
        },
    });
    return list;
  }

  Future<void> _openById() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Open by grievance ID'),
        content: Material(
          color: Colors.transparent,
          child: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g. MW-C2F1127C'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Open')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final id = await StaffData.idForReference(code);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No grievance found with ID ${code.trim().toUpperCase()}.')));
    } else {
      _open(id);
    }
  }

  void _open(String id) {
    if (context.isCompact) {
      context.push('/staff/case/$id').then((_) => _load());
    } else {
      setState(() => _selected = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final list = Scaffold(
      appBar: AppBar(
        title: const Text('Grievances'),
        actions: [
          if (s.caps.aiEnabled) IconButton(tooltip: 'AI assistant', onPressed: () => context.push('/staff/assistant'), icon: const Icon(Icons.auto_awesome)),
          IconButton(tooltip: 'Open by ID', onPressed: _openById, icon: const Icon(Icons.tag)),
          PopupMenuButton<SortKey>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortKey.newest, child: Text('Newest first')),
              PopupMenuItem(value: SortKey.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: SortKey.priority, child: Text('Highest priority')),
            ],
          ),
        ],
      ),
      floatingActionButton: s.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/staff/new').then((_) => _load()),
              icon: const Icon(Icons.add),
              label: const Text('New grievance'),
            )
          : null,
      body: _error != null
          ? ErrorBox('Could not load grievances.', onRetry: _load)
          : rows == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator.adaptive(onRefresh: _load, child: _listBody(rows)),
    );
    return TwoPane(
      primaryFraction: 0.42,
      primary: list,
      secondary: _selected == null
          ? const Scaffold(body: Center(child: Text('Select a grievance', style: TextStyle(color: Brand.muted))))
          : CaseDetailScreen(key: ValueKey(_selected), id: _selected!, embedded: true, onChanged: _load),
    );
  }

  Widget _listBody(List<DbRow> rows) {
    final visible = _visible();
    final open = rows.where((g) => !isClosed(g['status'] as String?));
    final persons = _personCounts;
    final page = visible.take(_shown).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
      // Status count tiles (tap to filter).
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in statuses.entries)
          FilterChip(
            selected: _filters.statuses.contains(e.key),
            onSelected: (v) => setState(() => v ? _filters.statuses.add(e.key) : _filters.statuses.remove(e.key)),
            label: Text('${e.value.en} · ${rows.where((g) => (g['status'] ?? 'received') == e.key).length}'),
          ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _concern("Women's safety", open.where(isWomenSafety).length, _filters.women, const Color(0xFFBE123C),
            (v) => setState(() => _filters.women = v)),
        _concern('Flooding', open.where((g) => g['flooding'] == true).length, _filters.flooding, const Color(0xFF0369A1),
            (v) => setState(() => _filters.flooding = v)),
        if (!s.caps.hideCorruption)
          _concern('Corruption', open.where((g) => g['corruption_type'] != null).length, _filters.corruption,
              const Color(0xFFB91C1C), (v) => setState(() => _filters.corruption = v)),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<Queue>(
          showSelectedIcon: false,
          segments: [
            const ButtonSegment(value: Queue.all, label: Text('All')),
            ButtonSegment(
                value: Queue.unassigned, label: Text('Unassigned (${open.where((g) => g['assigned_to'] == null).length})')),
            const ButtonSegment(value: Queue.groups, label: Text('My groups')),
            const ButtonSegment(value: Queue.me, label: Text('Assigned to me')),
          ],
          selected: {_queue},
          onSelectionChanged: (v) => setState(() {
            _queue = v.first;
            _shown = 50;
          }),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search ref, name, phone, area…', isDense: true),
            onChanged: (v) => setState(() {
              _q = v;
              _shown = 50;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: _filters.count > 0,
          label: Text('${_filters.count}'),
          child: OutlinedButton.icon(onPressed: _openFilters, icon: const Icon(Icons.tune, size: 18), label: const Text('Filters')),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('${visible.length} shown', style: const TextStyle(color: Brand.muted, fontSize: 12)),
      ),
      for (final g in page)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CaseCard(
            g: g,
            selected: g['id'] == _selected,
            repeat: persons[personKey(g)] ?? 1,
            group: _groups[g['assigned_group']],
            department: _departments.where((d) => d.id == g['department_id']).firstOrNull?.name,
            onTap: () => _open('${g['id']}'),
          ),
        ),
      if (visible.length > _shown)
        OutlinedButton(onPressed: () => setState(() => _shown += 50), child: Text('Show more (${visible.length - _shown} left)')),
    ]);
  }

  Widget _concern(String label, int openCount, bool on, Color color, ValueChanged<bool> set) => FilterChip(
        selected: on,
        onSelected: set,
        selectedColor: color.withValues(alpha: 0.15),
        avatar: Icon(Icons.warning_amber_rounded, size: 16, color: color),
        label: Text('$label ($openCount open)'),
      );

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        void toggle(Set<String> s, String v) => set(() => setState(() => s.contains(v) ? s.remove(v) : s.add(v)));
        Widget group(String title, Set<String> sel, Map<String, String> options) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final o in options.entries)
                    FilterChip(label: Text(o.value), selected: sel.contains(o.key), onSelected: (_) => toggle(sel, o.key)),
                ]),
              ]),
            );
        Widget check(String label, bool v, void Function(bool) on) =>
            CheckboxListTile.adaptive(dense: true, contentPadding: EdgeInsets.zero, title: Text(label), value: v, onChanged: (x) => set(() => setState(() => on(x ?? false))));
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Row(children: [
              const Expanded(child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => set(() => setState(_filters.clear)), child: const Text('Clear filters')),
            ]),
            group('Status', _filters.statuses, {for (final e in statuses.entries) e.key: e.value.en}),
            group('Constituency', _filters.constituencies, {for (final c in constituencies) c.key: c.en, 'none': 'Not specified'}),
            group('Category', _filters.categories, {for (final e in categories.entries) e.key: e.value.en}),
            group('Priority', _filters.priorities, {for (final p in priorityLevels) p: p[0].toUpperCase() + p.substring(1)}),
            if (_departments.isNotEmpty) group('Department', _filters.departments, {for (final d in _departments) d.id: d.name}),
            check('Pending public requests', _filters.pendingPublic, (v) => _filters.pendingPublic = v),
            check('Repeat complainants', _filters.repeat, (v) => _filters.repeat = v),
            check('Contact center', _filters.contactCenter, (v) => _filters.contactCenter = v),
          ]),
        );
      }),
    );
  }
}

/// Phone case card, ported from StaffCaseCard.tsx.
class CaseCard extends StatelessWidget {
  const CaseCard({super.key, required this.g, required this.onTap, this.selected = false, this.repeat = 1, this.group, this.department});
  final DbRow g;
  final VoidCallback onTap;
  final bool selected;
  final int repeat;
  final String? group, department;

  @override
  Widget build(BuildContext context) {
    final s = StaffSession.instance;
    final urgent = isUrgentCase(g);
    final level = g['priority_level'] as String?;
    final pc = priorityColors(level);
    final created = parseDate(g['created_at']);
    final flag = g['priority_flag'] as String?;
    final assignee = g['assigned_to'] as String?;
    Widget kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Brand.muted)),
          Text(v, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]);
    return Card(
      color: selected ? const Color(0xFFFEF2F2) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: urgent ? Brand.red.withValues(alpha: 0.4) : Brand.border, width: urgent ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${g['reference_code']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Brand.red)),
              const SizedBox(width: 6),
              SourceBadge(g),
              const Spacer(),
              StatusPill(g['status'] as String?),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Pill('${level ?? 'Unscored'}${g['priority_score'] != null ? ' · ${g['priority_score']}' : ''}', bg: pc.bg, fg: pc.fg),
              if (isWomenSafety(g)) const Pill("Women's safety", bg: Color(0xFFBE123C), fg: Colors.white),
              if (flag != null && flag != 'none' && flag != 'women_safety') Pill(flagLabel(flag), bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C)),
              if (g['flooding'] == true) const Pill('Flooding', bg: Color(0xFF0369A1), fg: Colors.white),
              if (corruptionLabel(g['corruption_type'] as String?) != null && !s.caps.hideCorruption)
                Pill(corruptionLabel(g['corruption_type'] as String?)!, bg: const Color(0xFFB91C1C), fg: Colors.white),
              if (g['urgency'] == 'high') const Pill('URGENT', bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C)),
              if (g['is_abusive'] == true) const Pill('ABUSE', bg: Color(0xFFDC2626), fg: Colors.white),
              if (g['public_requested'] == true) Pill(g['public_approved'] == true ? 'PUBLIC' : 'PUBLIC?'),
            ]),
            const SizedBox(height: 8),
            Text('${g['summary'] ?? g['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (c, box) {
              final cols = box.maxWidth > 420 ? 3 : 2;
              final w = (box.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final cell in [
                  kv('Citizen', [g['name'], g['contact']].whereType<String>().join(' · ')),
                  kv('Category', catLabel(g['category'] as String?)),
                  kv('Constituency', '${constituencyLabel(g['constituency'] as String?)}${g['ward_number'] != null ? ' · Ward ${g['ward_number']}' : ''}'),
                  kv('Filed', created == null ? '—' : Lang.instance.date(created)),
                  kv('Assigned to', assignee != null ? s.nameOf(assignee) : group != null ? 'Not picked yet · $group' : 'Unassigned'),
                  kv('Days pending', pendingLabel(g)),
                ])
                  SizedBox(width: w, child: cell),
              ]);
            }),
            if (department != null) ...[
              const SizedBox(height: 6),
              Text('Department: $department', style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ],
            if (repeat > 1) ...[
              const SizedBox(height: 4),
              Pill('×$repeat complaints by this citizen', bg: const Color(0xFFEDE9FE), fg: const Color(0xFF5B21B6)),
            ],
          ]),
        ),
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.g, {super.key});
  final DbRow g;
  @override
  Widget build(BuildContext context) {
    final cc = g['source'] == 'contact_center';
    final by = cc && g['created_by'] != null ? ' · ${StaffSession.instance.nameOf(g['created_by'] as String)}' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: cc ? const Color(0xFFFFF7D6) : const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(4)),
      child: Text(cc ? 'CONTACT CENTER$by' : 'PUBLIC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
