import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history_export_controller.dart';
import '../../application/history_provider.dart';
import '../../domain/services/device_service.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/export_strings.dart';
import '../widgets/form_widgets.dart';

/// Opens the export sheet for [device] (requirement 6.6, mockup 33).
Future<void> showExportSheet(BuildContext context, UserDevice device) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.tokens.surface,
  builder: (_) => ExportSheet(device: device),
);

/// "Export history": CSV file or PDF report of the device's last days, then the share sheet. A
/// spinner shows while the file is made; the sheet closes once it is shared, or says it failed.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.device});

  final UserDevice device;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportFormat _format = ExportFormat.csv;
  bool _failed = false;

  Future<void> _export() async {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final primary = Theme.of(context).colorScheme.primary;
    setState(() => _failed = false);
    final done = await ref
        .read(historyExportControllerProvider.notifier)
        .export(
          widget.device,
          _format,
          text: (content) => l10n.exportText(widget.device.name, content),
          colours: ExportColours(
            primary: primary.toARGB32(),
            barSoft: tokens.barSoft.toARGB32(),
            warn: tokens.warn.toARGB32(),
            danger: tokens.danger.toARGB32(),
            muted: tokens.muted.toARGB32(),
            border: tokens.border.toARGB32(),
          ),
        );
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final busy = ref.watch(historyExportControllerProvider).isLoading;
    final days = ref.watch(historyWindowProvider);
    return PopScope(
      // The file is being made and shared; the sheet closes by itself afterwards.
      canPop: !busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.exportSheetTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.exportSheetDescription(widget.device.name, days),
                style: TextStyle(fontSize: 14, height: 1.45, color: tokens.muted),
              ),
              const SizedBox(height: 12),
              Semantics(
                container: true,
                label: l10n.exportFormatsSpoken,
                child: RadioGroup<ExportFormat>(
                  groupValue: _format,
                  onChanged: (f) {
                    if (!busy && f != null) setState(() => _format = f);
                  },
                  child: Column(
                    children: [
                      _option(l10n.exportCsvTitle, l10n.exportCsvText, ExportFormat.csv),
                      Divider(height: 1, color: tokens.border),
                      _option(l10n.exportPdfTitle, l10n.exportPdfText, ExportFormat.pdf),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: l10n.exportShare,
                busyLabel: l10n.exportBusy,
                busy: busy,
                onPressed: _export,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.exportFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String title, String subtitle, ExportFormat format) => RadioListTile<ExportFormat>(
    value: format,
    controlAffinity: ListTileControlAffinity.trailing,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: context.tokens.muted)),
  );
}
