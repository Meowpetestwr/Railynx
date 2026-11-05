import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/tokens.dart';
import '../engine/vless_scanner.dart';
import 'widgets.dart';

/// Custom-mode picker: choose one of the scan results for a config row,
/// or type an IP by hand. A typed IP is only accepted when the scan
/// actually found it — anything else gets an inline error (the user's
/// requirement: a custom IP outside the found set must error, not pass).
/// Ships as a dialog rather than the floating popup of ui.html (see
/// PORT_NOTES). [results] overrides the candidate list (multi-config
/// rows pick from their own server's results).
class IpPickerDialog extends StatefulWidget {
  const IpPickerDialog({super.key, required this.controller, required this.rowIndex, this.results});

  final AppController controller;
  final int rowIndex;
  final List<ScanResult>? results;

  @override
  State<IpPickerDialog> createState() => _IpPickerDialogState();
}

class _IpPickerDialogState extends State<IpPickerDialog> {
  final TextEditingController _typed = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  List<ScanResult> get _results => widget.results ?? widget.controller.results;

  static final RegExp _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  void _applyTyped() {
    final ip = _typed.text.trim();
    final match = _ipv4.firstMatch(ip);
    final wellFormed =
        match != null && match.groups(<int>[1, 2, 3, 4]).every((g) => int.parse(g!) <= 255);
    if (!wellFormed) {
      setState(() => _error = 'Enter a valid IPv4 address.');
      return;
    }
    if (!_results.any((r) => r.ip == ip)) {
      setState(() => _error = 'That IP is not among the clean IPs found.');
      return;
    }
    widget.controller.pickIp(widget.rowIndex, ip);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final current = widget.rowIndex < c.rows.length ? c.rows[widget.rowIndex].ip : null;
    return Dialog(
      backgroundColor: Tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Tokens.edge.withValues(alpha: 0.14)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: SectionLabel('Choose an IP for config #${widget.rowIndex + 1}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _typed,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _applyTyped(),
                      decoration: InputDecoration(
                        hintText: 'Type an IP — 69.46.46.7',
                        hintStyle: const TextStyle(
                          fontFamily: Tokens.monoFont,
                          fontSize: 12,
                          color: Tokens.placeholder,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Tokens.inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Tokens.inputEdge),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Tokens.inputEdge),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Tokens.teal.withValues(alpha: 0.7)),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: Tokens.monoFont,
                        fontSize: 13,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChipButton(label: 'Use', onPressed: _applyTyped),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.poor),
                ),
              ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final r in _results)
                    InkWell(
                      onTap: () {
                        c.pickIp(widget.rowIndex, r.ip);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 18,
                              child: r.ip == current
                                  ? const Icon(Icons.check_rounded, size: 16, color: Tokens.fast)
                                  : null,
                            ),
                            IpText(r.ip, size: 14),
                            const Spacer(),
                            LatencyChip(ms: r.delayMs),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
