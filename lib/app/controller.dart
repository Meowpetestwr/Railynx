import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/vless_parser.dart';
import '../engine/vless_scanner.dart';
import 'fps.dart';
import 'look.dart';
import 'prefs_store.dart';
import 'probe_engine.dart';
import 'workbench_model.dart';

enum ScanStatus { idle, scanning, done, stopped, error }

/// All app state and actions. The widgets only read this and call its methods.
class AppController extends ChangeNotifier {
  AppController({required this.engine, PrefsStore? prefs}) : _prefs = prefs {
    _loadPrefs();
    domain.addListener(_domainChanged);
    subnet.addListener(_fieldChanged);
    configOpen = domain.text.trim().isEmpty;
  }

  static const int scanTotal = 254;
  static const String defaultSubnet = '69.46.46.';
  static const String appVersion = '2.1.0';

  final ProbeEngine engine;
  final PrefsStore? _prefs;

  /// Shown as a SnackBar by the UI. Set by the page on mount.
  void Function(String message)? toast;

  final TextEditingController domain = TextEditingController();
  final TextEditingController uuid = TextEditingController();
  final TextEditingController path = TextEditingController();
  final TextEditingController subnet = TextEditingController(text: defaultSubnet);
  final TextEditingController link = TextEditingController();

  String? parseHint;
  bool parseHintOk = false;
  VlessConfig? parsed;
  int activePort = 443;
  bool configOpen = false;
  bool animatedAurora = true;

  // ---- appearance & performance -------------------------------------------
  //
  // Every visual effect that costs GPU/CPU has its own switch, and three
  // presets bundle them. The DEFAULT is 'original' — the full design as
  // it was before any optimisation pass (the user's order after the
  // overlay readings): nothing is silently lightened; every trade-off
  // lives here as a switch with an explanation in Settings.
  // [uiPreset] is derived from the switch values — touch any switch
  // and the preset reads 'custom'. All values persist.

  bool fxBlobs = true;
  bool fxWashes = true;
  bool fxDockBlur = true;
  bool fxButtonFlow = true;
  bool fxRingGlow = true;
  bool fxRowAnimations = true;

  /// Rich shadows: the original deep, soft shadows under cards,
  /// buttons and sheets. Off swaps in the light set (the raster-diet
  /// values) — flatter, cheaper per frame.
  bool fxRichShadows = true;

  /// Blurred glows: real blur-filter passes for the ring halo and
  /// picks. Off paints stepped halos instead — same read, no filter.
  bool fxGlowBlur = true;

  /// Aurora rasterised at half resolution and upscaled by the
  /// compositor: a quarter of the pixels for the same picture.
  bool fxHalfRes = false;

  /// Settled result rows drop their entrance compositing layer as
  /// soon as the animation ends. Invisible; pure speed when many
  /// results are on screen.
  bool fxLiteRows = true;

  /// Display refresh-rate cap (Android): 0 = the panel's maximum,
  /// otherwise 60 or 30. Applied through the platform channel.
  int fpsLimit = 0;

  static const Map<String, Map<String, bool>> presetTable = <String, Map<String, bool>>{
    // The default look is the ORIGINAL one — the full design as it was
    // before any optimisation pass (the user's order): every effect at
    // its rich setting. The optimisations live in the switches below
    // it, each with its own explanation in Settings.
    'original': <String, bool>{
      'anim': true, 'blobs': true, 'washes': true, 'dockBlur': true,
      'buttonFlow': true, 'ringGlow': true, 'rowAnim': true,
      'rich': true, 'glowBlur': true, 'halfRes': false,
    },
    'balanced': <String, bool>{
      'anim': false, 'blobs': true, 'washes': true, 'dockBlur': true,
      'buttonFlow': false, 'ringGlow': true, 'rowAnim': true,
      'rich': false, 'glowBlur': false, 'halfRes': true,
    },
    'performance': <String, bool>{
      'anim': false, 'blobs': false, 'washes': false, 'dockBlur': false,
      'buttonFlow': false, 'ringGlow': false, 'rowAnim': false,
      'rich': false, 'glowBlur': false, 'halfRes': true,
    },
  };

  Map<String, bool> get _fxValues => <String, bool>{
        'anim': animatedAurora,
        'blobs': fxBlobs,
        'washes': fxWashes,
        'dockBlur': fxDockBlur,
        'buttonFlow': fxButtonFlow,
        'ringGlow': fxRingGlow,
        'rowAnim': fxRowAnimations,
        'rich': fxRichShadows,
        'glowBlur': fxGlowBlur,
        'halfRes': fxHalfRes,
      };

  /// The preset the current switch values match, or 'custom'.
  String get uiPreset {
    final values = _fxValues;
    for (final entry in presetTable.entries) {
      var match = true;
      for (final key in values.keys) {
        if (entry.value[key] != values[key]) {
          match = false;
          break;
        }
      }
      if (match) {
        return entry.key;
      }
    }
    return 'custom';
  }

  void _saveFx() {
    _prefs?.merge(<String, Object?>{
      'aurora_anim': animatedAurora,
      'fx_blobs': fxBlobs,
      'fx_washes': fxWashes,
      'fx_dock_blur': fxDockBlur,
      'fx_button_flow': fxButtonFlow,
      'fx_ring_glow': fxRingGlow,
      'fx_row_anim': fxRowAnimations,
      'fx_rich_shadows': fxRichShadows,
      'fx_glow_blur': fxGlowBlur,
      'fx_half_res': fxHalfRes,
      'fx_lite_rows': fxLiteRows,
    });
    _syncLook();
  }

  /// Mirror the paint-level flags into [Look] for widgets that have no
  /// controller handle (card shadows, glows, the sheet).
  void _syncLook() {
    Look.richShadows = fxRichShadows;
    Look.glowBlur = fxGlowBlur;
    Look.liteRows = fxLiteRows;
  }

  /// Apply one preset bundle ('full' | 'balanced' | 'performance').
  void applyPreset(String name) {
    final table = presetTable[name];
    if (table == null) {
      return;
    }
    animatedAurora = table['anim']!;
    fxBlobs = table['blobs']!;
    fxWashes = table['washes']!;
    fxDockBlur = table['dockBlur']!;
    fxButtonFlow = table['buttonFlow']!;
    fxRingGlow = table['ringGlow']!;
    fxRowAnimations = table['rowAnim']!;
    fxRichShadows = table['rich']!;
    fxGlowBlur = table['glowBlur']!;
    fxHalfRes = table['halfRes']!;
    _saveFx();
    _notify();
  }

  /// Set the display refresh-rate cap (0 = max, 60, 30) and apply it.
  void setFpsLimit(int v) {
    fpsLimit = v;
    _prefs?.merge(<String, Object?>{'fps_limit': v});
    applyFpsLimit(v);
    _notify();
  }

  /// Change individual switches; omitted ones stay as they are.
  void setFx({
    bool? anim,
    bool? blobs,
    bool? washes,
    bool? dockBlur,
    bool? buttonFlow,
    bool? ringGlow,
    bool? rowAnimations,
    bool? richShadows,
    bool? glowBlur,
    bool? halfRes,
    bool? liteRows,
  }) {
    if (anim != null) animatedAurora = anim;
    if (blobs != null) fxBlobs = blobs;
    if (washes != null) fxWashes = washes;
    if (dockBlur != null) fxDockBlur = dockBlur;
    if (buttonFlow != null) fxButtonFlow = buttonFlow;
    if (ringGlow != null) fxRingGlow = ringGlow;
    if (rowAnimations != null) fxRowAnimations = rowAnimations;
    if (richShadows != null) fxRichShadows = richShadows;
    if (glowBlur != null) fxGlowBlur = glowBlur;
    if (halfRes != null) fxHalfRes = halfRes;
    if (liteRows != null) fxLiteRows = liteRows;
    _saveFx();
    _notify();
  }

  ScanStatus status = ScanStatus.idle;
  int scanned = 0;
  List<ScanResult> results = <ScanResult>[];
  String? currentIp;
  String? _error;
  String? _statusOverride;
  bool _stopRequested = false;

  int genCount = defaultGenCount;
  String genMode = 'top';
  final Map<int, String> custom = <int, String>{};
  final Map<String, Tested> tested = <String, Tested>{};
  bool testing = false;
  Set<String> testingIps = <String>{};
  List<ConfigRow> rows = <ConfigRow>[];
  String? genText;
  String? genFeedback;
  int? copiedRow;
  String? copiedIp;

  Timer? _deltaTimer;
  Timer? _linkTimer;
  Timer? _settingsTimer;
  Timer? _progressTimer;
  bool _progressDirty = false;
  ScanAbort? _scanAbort;
  final Map<String, Timer> _feedbackTimers = <String, Timer>{};

  bool get scanning => status == ScanStatus.scanning;
  bool get hasResults => results.isNotEmpty;
  Map<String, int> get delays => WorkbenchModel.delayByIp(results);

  // ---- multi-config state ---------------------------------------------------
  //
  // When the pasted text holds several configs, [parsedAll] keeps them
  // all. Configs are grouped by the fields a probe actually depends on
  // (domain/SNI, uuid, path, port): one group = one scan. Configs from
  // the same subscription share all four, so they scan once, as before;
  // different servers scan one by one. [results] always shows the ACTIVE
  // group's list; [groupResults] holds every group's.

  /// All configs from the last parsed paste (empty in manual-fields mode).
  List<VlessConfig> parsedAll = <VlessConfig>[];

  /// Scan results per group key, filled by the multi-group scan.
  final Map<String, List<ScanResult>> groupResults = <String, List<ScanResult>>{};

  /// Which group's results [results] currently mirrors.
  int activeGroup = 0;

  /// 'Server 2 of 3' while a multi-group scan is running.
  String scanGroupNote = '';

  static String groupKeyOf(VlessConfig cfg) => '${cfg.domain}|${cfg.port}|${cfg.path}|${cfg.uuid}';

  /// One representative config per group, in paste order.
  List<VlessConfig> get groupLeaders {
    final seen = <String>{};
    final out = <VlessConfig>[];
    for (final cfg in parsedAll) {
      if (seen.add(groupKeyOf(cfg))) {
        out.add(cfg);
      }
    }
    return out;
  }

  bool get multiConfigs => parsedAll.length > 1;
  bool get multiGroups => groupLeaders.length > 1;
  bool get hasAnyResults => multiGroups
      ? groupResults.values.any((l) => l.isNotEmpty)
      : hasResults;

  List<ScanResult> resultsForConfig(int configIndex) {
    if (configIndex < 0 || configIndex >= parsedAll.length) {
      return const <ScanResult>[];
    }
    return groupResults[groupKeyOf(parsedAll[configIndex])] ?? const <ScanResult>[];
  }

  Map<String, int> delaysForConfig(int configIndex) =>
      WorkbenchModel.delayByIp(resultsForConfig(configIndex));

  /// Test-measurement key: in multi mode the same IP can be clean for
  /// two different servers with different delays, so measurements are
  /// kept per config; single mode keeps the plain IP key.
  String testKey(int configIndex, String ip) => multiConfigs ? '$configIndex|$ip' : ip;

  void selectGroup(int index) {
    final leaders = groupLeaders;
    if (index < 0 || index >= leaders.length || index == activeGroup) {
      return;
    }
    activeGroup = index;
    results = List<ScanResult>.of(groupResults[groupKeyOf(leaders[index])] ?? const <ScanResult>[]);
    _refreshRows();
    _notify();
  }

  /// Multi-mode shortage: some group has more configs than clean IPs.
  bool get anyShortage {
    if (genMode == 'best') {
      return false;
    }
    final leaders = groupLeaders;
    for (final leader in leaders) {
      final key = groupKeyOf(leader);
      final inGroup = parsedAll.where((cfg) => groupKeyOf(cfg) == key).length;
      final found = (groupResults[key] ?? const <ScanResult>[]).length;
      if (found > 0 && inGroup > found) {
        return true;
      }
    }
    return false;
  }

  int get shortageResultCount {
    var smallest = 0;
    var first = true;
    for (final leader in groupLeaders) {
      final found = (groupResults[groupKeyOf(leader)] ?? const <ScanResult>[]).length;
      if (found > 0 && (first || found < smallest)) {
        smallest = found;
        first = false;
      }
    }
    return smallest;
  }

  String get statusLine {
    if (_statusOverride != null) {
      return _statusOverride!;
    }
    switch (status) {
      case ScanStatus.idle:
        return 'Ready — paste a VLESS config to begin.';
      case ScanStatus.scanning:
        return 'Scanning… ${results.length} clean found so far.';
      case ScanStatus.done:
        return 'Scan completed! Found ${results.length} 100% verified clean IPs.';
      case ScanStatus.stopped:
        return 'Scan stopped. ${results.length} clean IPs found.';
      case ScanStatus.error:
        return _error ?? 'Something went wrong.';
    }
  }

  bool get statusIsError => status == ScanStatus.error && _statusOverride == null;

  String get configSummary {
    final d = domain.text.trim();
    final s = subnet.text.trim();
    if (d.isEmpty) {
      return 'No config loaded';
    }
    return s.isEmpty ? d : '$d  ·  ${s}x';
  }

  void _notify() => notifyListeners();

  /// Scan progress fires once per probed IP — up to 254 full page
  /// rebuilds for one scan, the main source of scan-time jank on the
  /// phone. State fields still update synchronously; only the listener
  /// notification is coalesced to one per ~90 ms (the first one is
  /// immediate, so the UI never lags behind the scan by more than that).
  void _notifyProgress() {
    if (_progressTimer == null) {
      _notify();
      _progressTimer = Timer(const Duration(milliseconds: 90), () {
        _progressTimer = null;
        if (_progressDirty) {
          _progressDirty = false;
          _notify();
        }
      });
    } else {
      _progressDirty = true;
    }
  }

  void _flushProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressDirty = false;
  }

  void _fieldChanged() => _notify();

  /// Editing the domain away from the parsed configs leaves multi mode:
  /// the fields now describe a different server than the paste did.
  void _domainChanged() {
    if (parsedAll.isNotEmpty && domain.text.trim() != parsedAll.first.domain) {
      parsedAll = <VlessConfig>[];
      groupResults.clear();
      scanGroupNote = '';
    }
    _notify();
  }

  void _loadPrefs() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final data = prefs.read();
    domain.text = _str(data['domain']);
    uuid.text = _str(data['uuid']);
    path.text = _str(data['path']);
    final sub = _str(data['subnet']);
    subnet.text = sub.isEmpty ? defaultSubnet : sub;
    final port = data['port'];
    activePort = (port is int && port >= 1 && port <= 65535) ? port : 443;
    final anim = data['aurora_anim'];
    animatedAurora = anim is bool ? anim : true;
    bool fx(String key) {
      final v = data[key];
      return v is bool ? v : true;
    }

    fxBlobs = fx('fx_blobs');
    fxWashes = fx('fx_washes');
    fxDockBlur = fx('fx_dock_blur');
    fxButtonFlow = fx('fx_button_flow');
    fxRingGlow = fx('fx_ring_glow');
    fxRowAnimations = fx('fx_row_anim');
    fxRichShadows = fx('fx_rich_shadows');
    fxGlowBlur = fx('fx_glow_blur');
    final hr = data['fx_half_res'];
    fxHalfRes = hr is bool ? hr : false;
    fxLiteRows = fx('fx_lite_rows');
    final fl = data['fps_limit'];
    fpsLimit = (fl is int && (fl == 0 || fl == 30 || fl == 60)) ? fl : 0;
    _syncLook();
    final count = data['gen_count'];
    if (count is int && count >= genMin && count <= genMax) {
      genCount = count;
    }
    final mode = data['gen_mode'];
    if (mode is String && modeOrder.contains(mode)) {
      genMode = mode;
    }
    rows = _computeRows();
  }

  static String _str(Object? value) => value is String ? value : '';

  List<ConfigRow> _computeRows() {
    if (multiConfigs) {
      return WorkbenchModel.assignmentsMulti(
        configs: parsedAll,
        resultsByGroup: groupResults,
        groupKey: groupKeyOf,
        mode: genMode,
        custom: custom,
      );
    }
    return WorkbenchModel.assignments(
      count: genCount,
      mode: genMode,
      results: results,
      custom: custom,
    );
  }

  void _refreshRows() {
    rows = _computeRows();
  }

  // ---- config and parsing -------------------------------------------------

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final trimmed = text.trim();
    if (trimmed.startsWith('vless://')) {
      link.text = trimmed;
      await parseLink(text);
    } else if (trimmed.isNotEmpty) {
      link.text = trimmed;
      _setHint('Clipboard does not contain a vless:// link.', ok: false);
    } else {
      _setHint(
        'Clipboard is empty or unreadable — paste the link in the field below.',
        ok: false,
      );
    }
  }

  void onLinkChanged(String value) {
    _linkTimer?.cancel();
    final v = value.trim();
    if (v.startsWith('vless://')) {
      _linkTimer = Timer(const Duration(milliseconds: 450), () => parseLink(v));
    }
  }

  Future<void> parseLink(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final (cfg, found) = parseFirst(trimmed);
    if (cfg == null) {
      _setHint('No valid vless:// link found.', ok: false);
      return;
    }
    parsed = cfg;
    parsedAll = parseAll(trimmed);
    groupResults.clear();
    activeGroup = 0;
    scanGroupNote = '';
    activePort = cfg.port;
    domain.text = cfg.domain;
    uuid.text = cfg.uuid;
    path.text = cfg.path;
    final String multi;
    if (parsedAll.length > 1) {
      final groups = groupLeaders.length;
      multi = '  ·  ${parsedAll.length} configs'
          '${groups > 1 ? ' · $groups servers' : ' · same server'}';
      // Rows now belong to the pasted configs; stale group results from
      // an earlier paste must not leak into them.
      results = <ScanResult>[];
      _onResultsChanged();
    } else if (found > 1) {
      multi = '  ·  used the first of $found links';
    } else {
      multi = '';
    }
    _setHint('Parsed VLESS: ${cfg.name}$multi', ok: true);
    _prefs?.merge(<String, Object?>{
      'domain': cfg.domain,
      'uuid': cfg.uuid,
      'path': cfg.path,
      'subnet': subnet.text.trim(),
      'port': cfg.port,
      'name': cfg.name,
    });
    _notify();
  }

  void _setHint(String text, {required bool ok}) {
    parseHint = text;
    parseHintOk = ok;
    _notify();
  }

  void toggleConfigOpen() {
    configOpen = !configOpen;
    _notify();
  }

  void setAnimatedAurora(bool on) {
    setFx(anim: on);
  }

  // ---- scanning -----------------------------------------------------------

  Future<void> toggleScan() async {
    if (scanning) {
      _stopRequested = true;
      // Kill in-flight probes at the socket level: the scan future now
      // returns within milliseconds instead of after the current probes
      // time out (~5 s, the user's report).
      _scanAbort?.abort();
      _statusOverride = 'Stopping…';
      _notify();
      return;
    }
    if (domain.text.trim().isEmpty || uuid.text.trim().isEmpty) {
      toast?.call('Paste a VLESS config first to load your server');
      _statusOverride = 'Please paste a VLESS config above to load your server.';
      _notify();
      return;
    }
    if (multiGroups) {
      await _scanGroups();
      return;
    }
    _statusOverride = null;
    _stopRequested = false;
    _scanAbort = ScanAbort();
    status = ScanStatus.scanning;
    scanned = 0;
    results = <ScanResult>[];
    currentIp = null;
    _onResultsChanged();
    _notify();

    final sub = subnet.text.trim().isEmpty ? defaultSubnet : subnet.text.trim();
    final prefix = sub.endsWith('.') ? sub : '$sub.';
    final leader = parsedAll.isEmpty ? null : groupLeaders.first;
    final finalResults = await engine.scan(
      subnetPrefix: prefix,
      domain: leader?.domain ?? domain.text.trim(),
      uuid: leader?.uuid ?? uuid.text.trim(),
      path: leader != null
          ? (leader.path.isEmpty ? '/' : leader.path)
          : (path.text.trim().isEmpty ? '/' : path.text.trim()),
      port: leader?.port ?? activePort,
      onProgress: (completed, total, result) {
        scanned = completed;
        currentIp = result.ip;
        if (result.isSuccess) {
          _insertSorted(result);
          _onResultsChanged();
        }
        _notifyProgress();
      },
      shouldStop: () => _stopRequested,
      abort: _scanAbort,
    );
    _flushProgress();
    results = finalResults;
    if (leader != null) {
      groupResults[groupKeyOf(leader)] = List<ScanResult>.of(finalResults);
    }
    _onResultsChanged();
    status = _stopRequested ? ScanStatus.stopped : ScanStatus.done;
    _statusOverride = null;
    _notify();
  }

  /// Multi-server scan: one full subnet scan per group, sequentially.
  /// The ring and the results list follow the group being scanned; at
  /// the end the view returns to the first group.
  Future<void> _scanGroups() async {
    final leaders = groupLeaders;
    _statusOverride = null;
    _stopRequested = false;
    _scanAbort = ScanAbort();
    status = ScanStatus.scanning;
    groupResults.clear();
    tested.clear();
    activeGroup = 0;
    _notify();

    final sub = subnet.text.trim().isEmpty ? defaultSubnet : subnet.text.trim();
    final prefix = sub.endsWith('.') ? sub : '$sub.';
    for (var gi = 0; gi < leaders.length; gi++) {
      if (_stopRequested) {
        break;
      }
      final leader = leaders[gi];
      activeGroup = gi;
      scanGroupNote = 'Server ${gi + 1} of ${leaders.length}';
      scanned = 0;
      results = <ScanResult>[];
      currentIp = null;
      _refreshRows();
      _notify();
      final res = await engine.scan(
        subnetPrefix: prefix,
        domain: leader.domain,
        uuid: leader.uuid,
        path: leader.path.isEmpty ? '/' : leader.path,
        port: leader.port,
        onProgress: (completed, total, result) {
          scanned = completed;
          currentIp = result.ip;
          if (result.isSuccess) {
            _insertSorted(result);
          }
          _notifyProgress();
        },
        shouldStop: () => _stopRequested,
        abort: _scanAbort,
      );
      groupResults[groupKeyOf(leader)] = res;
      results = res;
      _refreshRows();
      _notify();
    }
    _flushProgress();
    scanGroupNote = '';
    activeGroup = 0;
    results = List<ScanResult>.of(
      groupResults[groupKeyOf(leaders.first)] ?? const <ScanResult>[],
    );
    _refreshRows();
    status = _stopRequested ? ScanStatus.stopped : ScanStatus.done;
    _statusOverride = null;
    _notify();
  }

  void _insertSorted(ScanResult r) {
    var at = results.length;
    for (var i = 0; i < results.length; i++) {
      if (results[i].delayMs > r.delayMs) {
        at = i;
        break;
      }
    }
    results = <ScanResult>[...results]..insert(at, r);
  }

  /// A new result set invalidates earlier test measurements. Custom picks stay.
  void _onResultsChanged() {
    tested.clear();
    _refreshRows();
  }

  // ---- workbench ----------------------------------------------------------

  void setCount(int n) {
    final clamped = n < genMin ? genMin : (n > genMax ? genMax : n);
    if (clamped == genCount) {
      _refreshRows();
      _notify();
      return;
    }
    genCount = clamped;
    _refreshRows();
    _persistGenSettings();
    _notify();
  }

  void setMode(String mode) {
    if (mode == genMode || !modeOrder.contains(mode)) {
      return;
    }
    genMode = mode;
    _refreshRows();
    _persistGenSettings();
    _notify();
  }

  void pickIp(int rowIndex, String ip) {
    custom[rowIndex] = ip;
    _refreshRows();
    _notify();
  }

  void _persistGenSettings() {
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 250), () {
      _prefs?.merge(<String, Object?>{'gen_count': genCount, 'gen_mode': genMode});
    });
  }

  /// Config source for building and testing: an explicit valid link in the
  /// field wins, then the parsed config, then the fields. Mirrors app.py.
  (VlessConfig?, String?) resolveBase() {
    final text = link.text.trim();
    if (text.startsWith('vless://')) {
      final (cfg, _) = parseFirst(text);
      if (cfg == null) {
        return (null, 'No valid vless:// link found');
      }
      return (cfg, null);
    }
    final base = parsed;
    if (base != null) {
      return (base, null);
    }
    if (domain.text.trim().isNotEmpty && uuid.text.trim().isNotEmpty) {
      return (
        VlessConfig(
          uuid: uuid.text.trim(),
          address: domain.text.trim(),
          port: activePort,
          domain: domain.text.trim(),
          path: path.text.trim().isEmpty ? '/' : path.text.trim(),
          name: 'Clean Railway',
        ),
        null,
      );
    }
    return (null, 'No config loaded — paste a VLESS link first.');
  }

  List<String>? _buildLinks(List<String> ips) {
    final (base, error) = resolveBase();
    if (base == null) {
      toast?.call(error ?? 'Could not build configs');
      return null;
    }
    return <String>[for (final ip in ips) buildConfigLink(base, ip)];
  }

  /// Links for workbench rows. Single mode builds from resolveBase();
  /// multi mode builds each row from ITS OWN pasted config, so that
  /// config's uuid, server and original name are preserved.
  List<String>? _linksForRows(List<ConfigRow> wanted) {
    if (!multiConfigs) {
      final ips = wanted.map((r) => r.ip).whereType<String>().toList();
      return _buildLinks(ips);
    }
    return <String>[
      for (final row in wanted)
        if (row.ip != null) buildConfigLink(parsedAll[row.configIndex], row.ip!),
    ];
  }

  /// The latency chip for one preview row, resolved against the row's
  /// own server (multi mode) or the single result list.
  ChipInfo chipForRow(ConfigRow row) {
    final ip = row.ip;
    if (!multiConfigs || ip == null) {
      return WorkbenchModel.chipFor(
        ip: ip,
        tested: tested,
        delays: delays,
        testingIps: testingIps,
        testing: testing,
      );
    }
    final key = testKey(row.configIndex, ip);
    final t = tested[key];
    return WorkbenchModel.chipFor(
      ip: ip,
      tested: t == null ? const <String, Tested>{} : <String, Tested>{ip: t},
      delays: delaysForConfig(row.configIndex),
      testingIps: testingIps.contains(key) ? <String>{ip} : const <String>{},
      testing: testing,
    );
  }

  Future<void> copyText(String text, {String? label}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (label != null) {
      toast?.call('Copied: $label');
    }
  }

  Future<void> copyIp(String ip) async {
    await copyText(ip);
    copiedIp = ip;
    _notify();
    _scheduleFeedbackReset('ip', const Duration(milliseconds: 1200), () {
      copiedIp = null;
    });
  }

  Future<void> copyTop5() async {
    final ips = results.take(5).map((r) => r.ip).toList();
    if (ips.isEmpty) {
      toast?.call('No clean IPs yet');
      return;
    }
    await copyText(ips.join('\n'));
    toast?.call('Top ${ips.length} IPs copied');
  }

  Future<void> copyAllIps() async {
    final ips = results.map((r) => r.ip).toList();
    if (ips.isEmpty) {
      toast?.call('No clean IPs found yet');
      return;
    }
    await copyText(ips.join('\n'), label: 'All Clean IPs');
  }

  Future<void> copyRowConfig(int index) async {
    if (index < 0 || index >= rows.length) {
      return;
    }
    final ip = rows[index].ip;
    if (ip == null) {
      return;
    }
    final links = _linksForRows(<ConfigRow>[rows[index]]);
    if (links == null || links.isEmpty) {
      return;
    }
    await copyText(links.first, label: 'Config #${index + 1}');
    copiedRow = index;
    _notify();
    _scheduleFeedbackReset('row', const Duration(milliseconds: 1400), () {
      copiedRow = null;
    });
  }

  Future<void> generateAndCopy() async {
    final wanted = rows.where((r) => r.ip != null).toList();
    if (wanted.isEmpty) {
      toast?.call('No clean IPs to generate configs from');
      return;
    }
    final links = _linksForRows(wanted);
    if (links == null) {
      return;
    }
    genText = links.join('\n');
    await copyText(genText!);
    toast?.call('${links.length} configs copied');
    genFeedback = 'Copied ${links.length}';
    _notify();
    _scheduleFeedbackReset('gen', const Duration(milliseconds: 1400), () {
      genFeedback = null;
    });
  }

  /// One timer per feedback channel, so a second copy cannot cancel the
  /// reset of the first one (which would leave its check icon stuck on).
  void _scheduleFeedbackReset(String key, Duration after, void Function() reset) {
    _feedbackTimers[key]?.cancel();
    _feedbackTimers[key] = Timer(after, () {
      _feedbackTimers.remove(key);
      reset();
      _notify();
    });
  }

  Future<void> testThese() async {
    if (testing) {
      return;
    }
    // (configIndex, ip) pairs, unique per config, in row order. The same
    // IP under two different servers is measured separately for each.
    final pairs = <(int, String)>[];
    final seen = <String>{};
    for (final row in rows) {
      final ip = row.ip;
      if (ip == null) {
        continue;
      }
      if (seen.add(testKey(row.configIndex, ip))) {
        pairs.add((row.configIndex, ip));
      }
    }
    if (pairs.isEmpty) {
      toast?.call('Nothing to test yet');
      return;
    }
    VlessConfig? singleBase;
    if (!multiConfigs) {
      final (base, error) = resolveBase();
      if (base == null) {
        toast?.call(error ?? 'Test failed');
        return;
      }
      singleBase = base;
    }
    testing = true;
    testingIps = <String>{for (final (ci, ip) in pairs) testKey(ci, ip)};
    _notify();
    try {
      final byConfig = <int, List<String>>{};
      for (final (ci, ip) in pairs) {
        (byConfig[ci] ??= <String>[]).add(ip);
      }
      for (final entry in byConfig.entries) {
        final base = multiConfigs ? parsedAll[entry.key] : singleBase!;
        final delayMap = multiConfigs ? delaysForConfig(entry.key) : delays;
        final previous = <String, int?>{
          for (final ip in entry.value)
            ip: _previousDelay(testKey(entry.key, ip), ip, delayMap),
        };
        final outcomes = await engine.testIps(ips: entry.value, config: base);
        for (final ip in entry.value) {
          final r = outcomes[ip];
          final key = testKey(entry.key, ip);
          if (r != null && r.isSuccess) {
            tested[key] = WorkbenchModel.measured(previous[ip], r.delayMs);
          } else {
            tested[key] = const Tested(dead: true);
          }
        }
      }
    } catch (_) {
      toast?.call('Test failed');
    }
    testing = false;
    testingIps = <String>{};
    _notify();
    _deltaTimer?.cancel();
    _deltaTimer = Timer(const Duration(milliseconds: 1900), () {
      for (final key in tested.keys.toList()) {
        tested[key] = tested[key]!.withoutDelta();
      }
      _notify();
    });
  }

  /// Previous delay for a fresh measurement: the last good test under
  /// this config's key, else the scan delay from [delayMap].
  int? _previousDelay(String key, String ip, Map<String, int> delayMap) {
    final t = tested[key];
    if (t != null && !t.dead) {
      return t.delayMs;
    }
    return delayMap[ip];
  }

  /// The config text for the Generate panel, or null before the first run.
  String? get generatedText => genText;

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _linkTimer?.cancel();
    _settingsTimer?.cancel();
    _progressTimer?.cancel();
    for (final t in _feedbackTimers.values) {
      t.cancel();
    }
    domain.dispose();
    uuid.dispose();
    path.dispose();
    subnet.dispose();
    link.dispose();
    super.dispose();
  }
}
