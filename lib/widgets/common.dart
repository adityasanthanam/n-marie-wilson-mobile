import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/meta.dart';
import '../core/theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final m = statusMeta(status);
    return Pill(m.label, bg: m.bg, fg: m.fg);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = const Color(0xFFF4F4F5), this.fg = const Color(0xFF3F3F46), this.icon});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// EN | த toggle, as in the web header.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    return TextButton(
      onPressed: () => lang.set(lang.ta ? 'en' : 'ta'),
      child: Text(lang.ta ? 'EN' : 'தமிழ்', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.kicker});
  final String text;
  final String? kicker;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kicker != null)
            Text(kicker!.toUpperCase(),
                style: const TextStyle(color: Brand.red, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: Brand.muted),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(L('Try again', 'மீண்டும் முயற்சி'))),
            ],
          ]),
        ),
      );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = true});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: error ? const Color(0xFFDC2626) : const Color(0xFF047857))),
      );
}

Future<void> openUrl(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Builds [builder] once [future] resolves, with loading and error states.
class FutureView<T> extends StatelessWidget {
  const FutureView({super.key, required this.future, required this.builder, this.onRetry});
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, s) {
          if (s.hasError) {
            return ErrorBox(L('Could not load. Check your connection.', 'ஏற்ற முடியவில்லை. இணைப்பைச் சரிபார்க்கவும்.'),
                onRetry: onRetry);
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator.adaptive());
          return builder(context, s.data as T);
        },
      );
}

class HelplineTile extends StatelessWidget {
  const HelplineTile({super.key, required this.label, required this.numbers, this.whatsapp = false});
  final String label;
  final List<String> numbers;
  final bool whatsapp;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
          if (label.isNotEmpty) Text(label, style: const TextStyle(fontSize: 14)),
          for (final n in numbers) ...[
            ActionChip(
              avatar: const Icon(Icons.call, size: 16),
              label: Text(n, style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => openUrl(telUri(n)),
            ),
            if (whatsapp)
              ActionChip(
                avatar: const Icon(Icons.chat, size: 16, color: Brand.online),
                label: const Text('WhatsApp'),
                onPressed: () => openUrl(waUri(n)),
              ),
          ],
        ]),
      );
}
