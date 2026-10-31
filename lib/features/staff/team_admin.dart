import 'package:flutter/material.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'data.dart';
import 'session.dart';

// Admin-only screens: Team (admin.team.tsx), Roles (RolesManager.tsx), Groups (admin.groups.tsx).
// Every write goes through the web's own server functions, which re-check admin rights.

String _err(Object e) => e is ApiException ? e.message : 'Network error. Check your connection and try again.';

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<bool> _confirm(BuildContext context, String title, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog.adaptive(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
        ],
      ),
    ) ==
    true;

Future<String?> _prompt(BuildContext context, String title, {String initial = '', String? hint, bool password = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Material(
        color: Colors.transparent,
        child: TextField(
          controller: c,
          autofocus: true,
          obscureText: password,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

/// Multi-select dialog; returns null when cancelled.
Future<Set<String>?> _pickMany(BuildContext context, String title, Map<String, String> options, Set<String> selected, {String? note}) =>
    showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final picked = {...selected};
        return StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 360,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(note, style: const TextStyle(fontSize: 12, color: Brand.muted)),
                    ),
                  for (final e in options.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: picked.contains(e.key),
                      title: Text(e.value),
                      onChanged: (v) => set(() => v == true ? picked.add(e.key) : picked.remove(e.key)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, picked), child: const Text('Save')),
            ],
          ),
        );
      },
    );

final _constituencyOptions = {for (final c in constituencies) c.key: c.en};

class _Member {
  _Member(this.id, this.email, this.first, this.last);
  final String id;
  final String? email;
  final String first, last;
  final roles = <String>{};
  List<String> constituencies = [];
  String get name => '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : email ?? 'Team member';
}

class _TeamData {
  _TeamData(this.members, this.roles, this.assignments, this.resets);
  final List<_Member> members;
  final List<DbRow> roles;
  final Map<String, Set<String>> assignments;
  final List<DbRow> resets;
}

Future<List<_Member>> _loadMembers() async {
  final rows = await Api.instance.staff('team') as List;
  final byId = <String, _Member>{};
  for (final r in rows) {
    final m = byId.putIfAbsent(
      '${r['user_id']}',
      () => _Member('${r['user_id']}', r['email'] as String?, '${r['first_name'] ?? ''}', '${r['last_name'] ?? ''}'),
    );
    m.roles.add('${r['role']}');
    m.constituencies = [for (final c in r['constituencies'] as List? ?? const []) '$c'];
  }
  return byId.values.toList();
}

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<_TeamData> _future = _fetch();
  String _q = '';

  Future<_TeamData> _fetch() async {
    final r = await Future.wait<dynamic>([_loadMembers(), Api.instance.staff('roles'), Api.instance.staff('team/reset-requests')]);
    final roles = r[1] as Map;
    final assignments = <String, Set<String>>{};
    for (final a in roles['assignments'] as List? ?? const []) {
      assignments.putIfAbsent('${a['user_id']}', () => {}).add('${a['role_profile_id']}');
    }
    return _TeamData(r[0] as List<_Member>, List<DbRow>.from(roles['roles'] as List? ?? const []), assignments, List<DbRow>.from(r[2] as List));
  }

  void _reload() => setState(() => _future = _fetch());

  Future<void> _do(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (mounted && done != null) _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    }
    _reload();
  }

  Future<void> _resetPassword(String userId, {String? requestId}) async {
    final p = await _prompt(context, 'Set new password', hint: '8 to 72 characters', password: true);
    if (p == null || p.isEmpty) return;
    if (p.length < 8 || p.length > 72) {
      if (mounted) _toast(context, 'The password must be 8 to 72 characters.');
      return;
    }
    await _do(() async {
      await Api.instance.staff('team/reset-password', body: {'user_id': userId, 'password': p});
      if (requestId != null) await Api.instance.staff('team/reset-requests/resolve', body: {'id': requestId});
    }, 'Password updated. Share it with them privately.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Team')),
    floatingActionButton: FutureBuilder<_TeamData>(
      future: _future,
      builder: (c, s) => s.hasData
          ? FloatingActionButton.extended(onPressed: () => _add(s.data!.roles), icon: const Icon(Icons.person_add_alt), label: const Text('Add member'))
          : const SizedBox.shrink(),
    ),
    body: FutureView<_TeamData>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final roleNames = {for (final r in d.roles) '${r['id']}': '${r['name']}'};
        final q = _q.toLowerCase();
        final members = d.members.where((m) => q.isEmpty || '${m.name} ${m.email}'.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return RefreshIndicator.adaptive(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.resets.isNotEmpty)
                      Card(
                        color: const Color(0xFFFFFBEB),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Password reset requests', style: TextStyle(fontWeight: FontWeight.w700)),
                              for (final r in d.resets)
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('${r['email']}'),
                                    if (parseDate(r['created_at']) != null)
                                      Text(Lang.instance.dateTime(parseDate(r['created_at'])!), style: const TextStyle(fontSize: 12, color: Brand.muted)),
                                    if (r['user_id'] != null)
                                      TextButton(
                                        onPressed: () => _resetPassword('${r['user_id']}', requestId: '${r['id']}'),
                                        child: const Text('Set new password'),
                                      ),
                                    TextButton(
                                      onPressed: () => _do(() => Api.instance.staff('team/reset-requests/resolve', body: {'id': r['id']})),
                                      child: const Text('Dismiss'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or email'),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                    const SizedBox(height: 8),
                    for (final m in members) _memberCard(m, d, roleNames),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _memberCard(_Member m, _TeamData d, Map<String, String> roleNames) {
    final admin = m.roles.contains('admin');
    final me = m.id == StaffSession.instance.uid;
    final profiles = [for (final id in d.assignments[m.id] ?? const <String>{}) roleNames[id] ?? 'Role'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(m.name + (me ? ' (you)' : '')),
        subtitle: Text(
          [
            if (m.email != null) m.email!,
            admin ? 'Admin · full access' : (profiles.isEmpty ? 'Staff' : profiles.join(', ')),
            m.constituencies.isEmpty || admin ? 'All constituencies' : m.constituencies.map(constituencyLabel).join(', '),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _action(v, m, d),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name', child: Text('Rename')),
            if (!admin) const PopupMenuItem(value: 'roles', child: Text('Roles')),
            if (!admin) const PopupMenuItem(value: 'constituencies', child: Text('Constituencies')),
            const PopupMenuItem(value: 'password', child: Text('Reset password')),
            if (!me) const PopupMenuItem(value: 'remove', child: Text('Remove access')),
          ],
        ),
      ),
    );
  }

  Future<void> _action(String action, _Member m, _TeamData d) async {
    switch (action) {
      case 'name':
        final first = await _prompt(context, 'First name', initial: m.first);
        if (first == null || first.isEmpty || !mounted) return;
        final last = await _prompt(context, 'Last name', initial: m.last);
        if (last == null || last.isEmpty) return;
        await _do(() => Api.instance.staff('team/name', body: {'user_id': m.id, 'first_name': first, 'last_name': last}));
      case 'roles':
        final picked = await _pickMany(context, 'Roles for ${m.name}', {for (final r in d.roles) '${r['id']}': '${r['name']}'}, d.assignments[m.id] ?? {});
        if (picked == null) return;
        if (picked.isEmpty) {
          if (mounted) _toast(context, 'Pick at least one role');
          return;
        }
        await _do(() => Api.instance.staff('roles/assign', body: {'user_id': m.id, 'role_profile_ids': picked.toList()}));
      case 'constituencies':
        final picked = await _pickMany(
          context,
          'Constituencies for ${m.name}',
          _constituencyOptions,
          m.constituencies.toSet(),
          note: 'Leave all unticked for access to every constituency.',
        );
        if (picked == null) return;
        await _do(() => Api.instance.staff('team/constituencies', body: {'user_id': m.id, 'constituencies': picked.toList()}));
      case 'password':
        await _resetPassword(m.id);
      case 'remove':
        if (!await _confirm(context, 'Remove ${m.name}\'s access?', 'Remove')) return;
        await _do(() async {
          for (final role in m.roles) {
            await Api.instance.staff('team/revoke', body: {'user_id': m.id, 'role': role});
          }
        }, 'Access removed.');
    }
  }

  Future<void> _add(List<DbRow> roles) async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AddMemberScreen(roles: roles)));
    if (added == true) _reload();
  }
}

class _AddMemberScreen extends StatefulWidget {
  const _AddMemberScreen({required this.roles});
  final List<DbRow> roles;
  @override
  State<_AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<_AddMemberScreen> {
  final _first = TextEditingController(), _last = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  String _role = 'staff';
  late String? _profile = widget.roles.where((r) => r['name'] == 'Staff').map((r) => '${r['id']}').firstOrNull;
  Set<String> _constituencies = {};
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final email = _email.text.trim(), password = _password.text;
    if (!email.contains('@')) return setState(() => _error = 'Enter a valid email.');
    final creating = password.isNotEmpty;
    if (creating) {
      if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) return setState(() => _error = 'Enter the first and last name.');
      if (password.length < 8 || password.length > 72) return setState(() => _error = 'The password must be 8 to 72 characters.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final common = {
      'email': email,
      'role': _role,
      'constituencies': _role == 'admin' ? <String>[] : _constituencies.toList(),
      if (_role == 'staff' && _profile != null) 'role_profile_id': _profile,
    };
    try {
      await Api.instance.staff(
        creating ? 'team/create' : 'team/grant',
        body: creating ? {...common, 'password': password, 'first_name': _first.text.trim(), 'last_name': _last.text.trim()} : common,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Add member'),
      actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Leave the password empty to give an existing account staff access.', style: TextStyle(color: Brand.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: _first,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                TextField(
                  controller: _last,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: true,
                  maxLength: 72,
                  decoration: const InputDecoration(labelText: 'Password (new accounts)'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'staff', label: Text('Staff')),
                    ButtonSegment(value: 'admin', label: Text('Admin')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (v) => setState(() => _role = v.first),
                ),
                if (_role == 'staff') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _profile,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [for (final r in widget.roles) DropdownMenuItem(value: '${r['id']}', child: Text('${r['name']}'))],
                    onChanged: (v) => setState(() => _profile = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Constituencies (none ticked = all)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in _constituencyOptions.entries)
                        FilterChip(
                          label: Text(e.value),
                          selected: _constituencies.contains(e.key),
                          onSelected: (v) => setState(() => _constituencies = v ? {..._constituencies, e.key} : ({..._constituencies}..remove(e.key))),
                        ),
                    ],
                  ),
                ],
                if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Notice(_error!)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late Future<List<DbRow>> _future = _fetch();
  Future<List<DbRow>> _fetch() async => List<DbRow>.from((await Api.instance.staff('roles') as Map)['roles'] as List? ?? const []);
  void _reload() => setState(() => _future = _fetch());

  static String summary(DbRow r) {
    if (r['can_view_grievances'] == false) return ['No grievance access', if (r['can_manage_news'] == true) 'Manages News Feed'].join(' · ');
    final hidden = (r['hidden_categories'] as List? ?? const []).length;
    return [
      r['can_edit'] == true ? 'Can make changes' : 'Read-only',
      r['ai_enabled'] == true ? 'AI on' : 'AI off',
      if (r['can_manage_news'] == true) 'Manages News Feed',
      if (r['hide_corruption'] == true) 'No corruption',
      if (r['hide_women_safety'] == true) "No women's safety",
      if (r['hide_flooding'] == true) 'No flooding',
      if (hidden > 0) '$hidden hidden categories',
    ].join(' · ');
  }

  Future<void> _edit(DbRow? r) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _RoleEditor(role: r)));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Roles')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New role')),
    body: FutureView<List<DbRow>>(
      future: _future,
      onRetry: _reload,
      builder: (context, roles) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          for (final r in roles)
            MaxWidth(
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${r['name']}'),
                  subtitle: Text(summary(r)),
                  onTap: () => _edit(r),
                  trailing: r['is_system'] == true
                      ? const Text('Built-in', style: TextStyle(fontSize: 12, color: Brand.muted))
                      : IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (!await _confirm(context, 'Delete role "${r['name']}"?', 'Delete')) return;
                            try {
                              await Api.instance.staff('roles/delete', body: {'id': r['id']});
                            } catch (e) {
                              if (context.mounted) _toast(context, _err(e));
                            }
                            _reload();
                          },
                        ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _RoleEditor extends StatefulWidget {
  const _RoleEditor({this.role});
  final DbRow? role;
  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  late final DbRow _r = {
    'name': '',
    'description': '',
    'hidden_categories': <String>[],
    'hide_corruption': false,
    'hide_women_safety': false,
    'hide_flooding': false,
    'ai_enabled': true,
    'can_edit': true,
    'can_manage_news': false,
    'can_view_grievances': true,
    ...?widget.role,
  };
  late final _name = TextEditingController(text: '${_r['name']}');
  late final _description = TextEditingController(text: '${_r['description'] ?? ''}');
  late final Set<String> _hidden = {for (final c in _r['hidden_categories'] as List? ?? const []) '$c'};
  bool _busy = false;
  String? _error;

  bool _flag(String k) => _r[k] == true;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2 || name.length > 60) return setState(() => _error = 'The name must be 2 to 60 characters.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final view = _flag('can_view_grievances');
    try {
      await Api.instance.staff(
        'roles/save',
        body: {
          if (widget.role != null) 'id': widget.role!['id'],
          'name': name,
          'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
          'hidden_categories': view ? _hidden.toList() : <String>[],
          for (final k in ['hide_corruption', 'hide_women_safety', 'hide_flooding', 'ai_enabled', 'can_edit']) k: view && _flag(k),
          'can_manage_news': _flag('can_manage_news'),
          'can_view_grievances': view,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _switch(String key, String label) =>
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(label), value: _flag(key), onChanged: (v) => setState(() => _r[key] = v));

  @override
  Widget build(BuildContext context) {
    final view = _flag('can_view_grievances');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == null ? 'New role' : 'Edit role'),
        actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: _description,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  _switch('can_view_grievances', 'Can access grievances (off = content only)'),
                  if (view) ...[_switch('can_edit', 'Can make changes'), _switch('ai_enabled', 'AI assistant')],
                  _switch('can_manage_news', 'Manage News Feed'),
                  if (view) ...[
                    _switch('hide_corruption', 'Hide corruption cases'),
                    _switch('hide_women_safety', "Hide women's safety cases"),
                    _switch('hide_flooding', 'Hide flooding cases'),
                    const SizedBox(height: 8),
                    const Text('Hidden categories', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in categories.entries)
                          FilterChip(
                            label: Text(e.value.en),
                            selected: _hidden.contains(e.key),
                            onSelected: (v) => setState(() => v ? _hidden.add(e.key) : _hidden.remove(e.key)),
                          ),
                      ],
                    ),
                  ],
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Notice(_error!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

typedef _GroupsData = ({List<DbRow> groups, Map<String, Set<String>> members, List<_Member> people});

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<_GroupsData> _future = _fetch();

  Future<_GroupsData> _fetch() async {
    final r = await Future.wait<dynamic>([
      supa.from('staff_groups').select('id, name, constituency').order('name'),
      supa.from('staff_group_members').select('group_id, user_id'),
      _loadMembers(),
    ]);
    final members = <String, Set<String>>{};
    for (final m in r[1] as List) {
      members.putIfAbsent('${m['group_id']}', () => {}).add('${m['user_id']}');
    }
    return (groups: List<DbRow>.from(r[0] as List), members: members, people: r[2] as List<_Member>);
  }

  void _reload() => setState(() => _future = _fetch());

  Future<void> _edit(_GroupsData d, DbRow? g) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _GroupEditor(group: g, members: g == null ? {} : d.members['${g['id']}'] ?? {}, people: d.people),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Groups')),
    floatingActionButton: FutureBuilder<_GroupsData>(
      future: _future,
      builder: (c, s) => s.hasData
          ? FloatingActionButton.extended(onPressed: () => _edit(s.data!, null), icon: const Icon(Icons.add), label: const Text('New group'))
          : const SizedBox.shrink(),
    ),
    body: FutureView<_GroupsData>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final names = {for (final p in d.people) p.id: p.name};
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            if (d.groups.isEmpty)
              const Center(
                child: Text('No groups yet.', style: TextStyle(color: Brand.muted)),
              ),
            for (final g in d.groups)
              MaxWidth(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${g['name']}'),
                    subtitle: Text(
                      [
                        g['constituency'] == null ? 'Manual assignment only' : 'Auto-routes ${constituencyLabel(g['constituency'] as String)}',
                        (d.members['${g['id']}'] ?? const <String>{}).map((id) => names[id] ?? 'Team member').join(', '),
                      ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                    onTap: () => _edit(d, g),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await _confirm(context, 'Delete "${g['name']}"? Its cases move to the unassigned queue.', 'Delete')) return;
                        try {
                          await Api.instance.staff('groups/delete', body: {'id': g['id']});
                        } catch (e) {
                          if (context.mounted) _toast(context, _err(e));
                        }
                        _reload();
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({this.group, required this.members, required this.people});
  final DbRow? group;
  final Set<String> members;
  final List<_Member> people;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: '${widget.group?['name'] ?? ''}');
  late String? _constituency = widget.group?['constituency'] as String?;
  late final Set<String> _members = {...widget.members};
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) return setState(() => _error = 'The group name must be at least 2 characters.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.staff(
        'groups/save',
        body: {if (widget.group != null) 'id': widget.group!['id'], 'name': name, 'constituency': _constituency, 'members': _members.toList()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = _err(e);
      setState(() => _error = msg.contains('duplicate') || msg.contains('23505') ? 'A group with that name already exists.' : msg);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final people = [...widget.people]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'New group' : 'Edit group'),
        actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _constituency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Constituency', helperText: 'New and unassigned open cases from it are routed to this group.'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None (manual assignment only)')),
                      for (final c in constituencies) DropdownMenuItem<String?>(value: c.key, child: Text(c.en)),
                    ],
                    onChanged: (v) => setState(() => _constituency = v),
                  ),
                  const SizedBox(height: 12),
                  Text('Members · ${_members.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  for (final p in people)
                    CheckboxListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _members.contains(p.id),
                      title: Text(p.name),
                      subtitle: p.email == null ? null : Text(p.email!),
                      onChanged: (v) => setState(() => v == true ? _members.add(p.id) : _members.remove(p.id)),
                    ),
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Notice(_error!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
