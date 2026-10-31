import 'package:flutter/material.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// YouTube / Instagram link detection from src/lib/news-media.ts.
({String thumb, Uri watch})? youtubeOf(String? url) {
  final u = url == null ? null : Uri.tryParse(url);
  if (u == null) return null;
  final host = u.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  String? id;
  if (host == 'youtu.be') {
    id = u.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final s = u.pathSegments;
    if (s.length >= 2 && (s[0] == 'shorts' || s[0] == 'embed')) id = s[1];
    if (s.firstOrNull == 'watch') id = u.queryParameters['v'];
  }
  if (id == null || !RegExp(r'^[\w-]{6,20}$').hasMatch(id)) return null;
  return (thumb: 'https://i.ytimg.com/vi/$id/hqdefault.jpg', watch: Uri.parse('https://www.youtube.com/watch?v=$id'));
}

bool isInstagram(String? url) {
  final u = url == null ? null : Uri.tryParse(url);
  return u != null && u.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '') == 'instagram.com' &&
      RegExp(r'^/(reel|reels|p)/[\w-]{4,40}').hasMatch(u.path);
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<Map<String, dynamic>>> _future = Api.instance.news(limit: 100);

  void _countView(String id) {
    // Same RPC the web's incrementNewsView calls; best effort.
    supa.rpc('increment_news_view', params: {'p_id': id}).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L('News Feed', 'செய்திகள்')), actions: const [LangToggle()]),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          setState(() => _future = Api.instance.news(limit: 100));
          await _future;
        },
        child: FutureView(
          future: _future,
          onRetry: () => setState(() => _future = Api.instance.news(limit: 100)),
          builder: (context, items) {
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(L('No updates yet. Please check back soon.', 'இன்னும் செய்திகள் இல்லை. விரைவில் பார்க்கவும்.'))),
              ]);
            }
            final maxViews = items.map((n) => (n['view_count'] as num?)?.toInt() ?? 0).fold(0, (a, b) => a > b ? a : b);
            final threshold = maxViews < 5 ? 1 << 30 : (maxViews * 0.6).ceil().clamp(5, 1 << 30);
            final rows = <Widget>[
              SectionTitle(L("The Minister's activities", 'அமைச்சரின் செயல்பாடுகள்'), kicker: L('News Feed', 'செய்திகள்')),
            ];
            String? lastDay;
            for (final n in items) {
              final d = parseDate(n['published_at'])?.toLocal();
              final day = d == null ? '' : _dayLabel(d, lang);
              if (day != lastDay) {
                rows.add(Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(day, style: const TextStyle(fontWeight: FontWeight.w600, color: Brand.muted))));
                lastDay = day;
              }
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NewsCard(n, trending: ((n['view_count'] as num?) ?? 0) >= threshold, onView: () => _countView('${n['id']}')),
              ));
            }
            return ListView(padding: const EdgeInsets.all(16), children: [MaxWidth(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows))]);
          },
        ),
      ),
    );
  }

  String _dayLabel(DateTime d, Lang lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return L('Today', 'இன்று');
    if (that == today.subtract(const Duration(days: 1))) return L('Yesterday', 'நேற்று');
    return lang.date(d, long: true);
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.n, {required this.trending, required this.onView});
  final Map<String, dynamic> n;
  final bool trending;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final link = n['link_url'] as String?;
    final yt = youtubeOf(link);
    final video = n['video_url'] as String?;
    final image = n['image_url'] as String?;
    Widget? media;
    if (video != null) {
      media = _PlayTile(label: L('Play video', 'காணொளியை இயக்கவும்'), onTap: () {
        onView();
        openUrl(Uri.parse(video));
      });
    } else if (yt != null) {
      media = _PlayTile(image: yt.thumb, label: L('Play video', 'காணொளியை இயக்கவும்'), onTap: () {
        onView();
        openUrl(yt.watch);
      });
    } else if (isInstagram(link)) {
      media = _PlayTile(label: L('Watch on Instagram', 'Instagram-இல் பார்க்கவும்'), onTap: () {
        onView();
        openUrl(Uri.parse(link!));
      });
    } else if (image != null) {
      media = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Image.network(image, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
      );
    }
    final date = parseDate(n['published_at']);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ?media,
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (date != null) Text(Lang.instance.date(date, long: true), style: const TextStyle(color: Brand.muted, fontSize: 12)),
              const Spacer(),
              if (trending)
                Pill(L('Trending', 'பிரபலம்'), icon: Icons.local_fire_department, bg: const Color(0xFFFFEDD5), fg: const Color(0xFFC2410C)),
            ]),
            const SizedBox(height: 6),
            Text('${n['title'] ?? ''}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if ((n['content'] as String?)?.isNotEmpty ?? false) ...[const SizedBox(height: 6), Text(n['content'] as String)],
            if (link != null && link.isNotEmpty) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () {
                  onView();
                  openUrl(Uri.parse(link));
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(L('Read more', 'மேலும் படிக்க')),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _PlayTile extends StatelessWidget {
  const _PlayTile({this.image, required this.label, required this.onTap});
  final String? image;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: Brand.ink,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              if (image != null) Image.network(image!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              Center(
                child: Semantics(
                  label: label,
                  button: true,
                  child: const CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.play_arrow, size: 34, color: Brand.red)),
                ),
              ),
            ]),
          ),
        ),
      );
}
