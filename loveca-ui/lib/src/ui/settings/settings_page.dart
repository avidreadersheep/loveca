/// R6 設定・診断（`docs/UI設計メモ.md` §2-2 / §2-6）.
///
/// ★★ この画面の役割は「いま何が効いているか」を 1 枚で見せること ★★
/// 起動 Notice は R2 のホームにしか出ず、画面を離れれば読めない。
/// **セッション中ずっと続く状態**（dist の場所・データ版・検索上限の上書き）は
/// 常設の置き場が要る。
///
/// ★★ 取り込みは起動ゲートでのみ走らせる（決定 D56）★★
/// 実行中に取り込むと、メモリ上の `MasterCatalog`（`cards` / `printings` / `rows`）と
/// そこから組んだ `DeckValidator` が**静かに古くなる。**
/// 間違った答えを返すが例外は出ない——A-3 と同じ型。
/// だからこの画面に「いま取り込む」ボタンは無い。**再起動を伴う操作**にしてある。
///
/// ★★ `import_issues` の出口はここである（決定 D39）★★
/// 記録するだけで誰も見ない状態にしない、というのが D39 の趣旨。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_settings.dart';
import '../../data/dist_locator.dart';
import '../../data/import_issue.dart';
import '../../data/search_limit.dart';
import '../../state/app_scope.dart';
import '../../state/store.dart';
import '../common/loadable_view.dart';
import 'import_issues_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppScope _scope;
  late TextEditingController _distController;

  /// ★`Loadable` で持つ。失敗を 0 件にすり替えない（決定 D53 / §3-4(2)）。
  Loadable<List<ImportIssue>> _issues = const Loading();

  AppSettings _settings = AppSettings.defaults;
  bool _needsRestart = false;
  bool _prepared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    if (_prepared) return;
    _prepared = true;
    _settings = _scope.environment.settings;
    _distController = TextEditingController(text: _settings.distDir ?? '');
    _loadIssues();
  }

  @override
  void dispose() {
    _distController.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    try {
      final issues = await _scope.environment.master.outstandingImportIssues();
      if (mounted) setState(() => _issues = Ready(issues));
    } on Object catch (error, stackTrace) {
      // ★握らない。読めなかったことと 0 件を同じ見た目にしない（決定 D53）。
      if (mounted) setState(() => _issues = Failed(error, stackTrace));
    }
  }

  Future<void> _saveSettings(AppSettings next) async {
    await _scope.environment.settingsStore.save(next);
    if (!mounted) return;
    setState(() {
      _settings = next;
      // ★dist の場所は起動ゲートでしか読まれない（決定 D56 / D60）。
      //   いま効いたように見せると、次の起動まで嘘をつくことになる。
      _needsRestart = true;
    });
    // ★★ 帯だけでは足りない ★★
    //   帯は一覧の先頭にあり、下のほうの項目を触った利用者には**見えない。**
    //   押した場所で言わないと「保存されたのか分からない」が残る。
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました。反映されるのは次の起動からです。')),
    );
  }

  Future<void> _quit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('アプリを終了しますか'),
        content: const Text(
          'カードデータの取り込みは起動のときだけ行います。\n'
          '終了したあと、もう一度起動すると取り込みを試みます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );
    if (ok == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final env = _scope.environment;
    final outcome = env.importOutcome;

    return Scaffold(
      appBar: AppBar(title: const Text('設定・診断')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_needsRestart)
            const _RestartBanner(),
          _Section(
            title: 'カードデータ',
            children: [
              // ★★ どの段で解決したかを出す（決定 D60）★★
              //   3 段の解決順を持つ以上、どれが効いているか分からないと
              //   「設定したのに変わらない」が原因不明のまま残る。
              _Row(
                label: 'いま使っている場所',
                value: outcome.location.source?.label ?? '見つかりませんでした',
              ),
              if (outcome.location.directory case final dir?)
                _Row(label: 'パス', value: dir.path, selectable: true),
              _Row(
                label: '取り込み済みのデータ版',
                value: '${env.catalog.dataVersion}',
              ),
              if (outcome.remoteDataVersion case final remote?)
                _Row(label: '配信物のデータ版', value: '$remote'),
              _Row(label: 'このアプリの版', value: env.appVersion),
              if (outcome.remoteMinAppVersion case final min?)
                _Row(label: 'データが要求する最小版', value: min),
              _Row(
                label: 'カード',
                value: '${env.catalog.cardCount} 種 '
                    '/ ${env.catalog.printingCount} 刷り',
              ),
              const SizedBox(height: 8),
              _UpdateHint(
                local: env.catalog.dataVersion,
                remote: outcome.remoteDataVersion,
                distMissing: outcome.distMissing,
              ),
              const SizedBox(height: 8),
              // ★★ 「いま取り込む」を置かない（決定 D56）★★
              OutlinedButton.icon(
                onPressed: _quit,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('アプリを終了する'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '★取り込みは起動のときだけ行います。'
                  '動かしている最中に取り込むと、'
                  '画面に出ているカードの一覧や検証が黙って古くなるためです。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          _Section(
            title: '探した場所',
            children: [
              // ★見つかったときも全部出す。どの段が飛ばされたかが分かる。
              for (final candidate in outcome.location.searched)
                _CandidateRow(
                  candidate: candidate,
                  used: candidate.source == outcome.location.source,
                ),
            ],
          ),
          _Section(
            title: 'カードデータの場所を指定する',
            children: [
              Text(
                '空にすると、環境変数か実行ファイルの隣の既定に戻ります。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('distDirField'),
                controller: _distController,
                decoration: const InputDecoration(
                  labelText: 'dist のパス',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () {
                    final text = _distController.text.trim();
                    _saveSettings(
                      text.isEmpty
                          // ★消す口が要る。`distDir ?? this.distDir` だけだと片道になる。
                          ? _settings.copyWith(clearDistDir: true)
                          : _settings.copyWith(distDir: text),
                    );
                  },
                  child: const Text('この場所を保存する'),
                ),
              ),
            ],
          ),
          _Section(
            title: '一覧の表示',
            children: [
              SwitchListTile(
                key: const Key('showParallelSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('パラレル刷りを最初から表示する'),
                subtitle: const Text('カード一覧を開いたときの既定です'),
                value: _settings.showParallel,
                onChanged: (v) =>
                    _saveSettings(_settings.copyWith(showParallel: v)),
              ),
            ],
          ),
          _Section(
            title: '取り込めなかったファイル',
            children: [
              // ★onError を渡さない = 既定でエラーが出る（決定 D53 / §3-4(1)）。
              LoadableView<List<ImportIssue>>(
                loadable: _issues,
                ready: (issues) => ImportIssuesSection(issues: issues),
              ),
            ],
          ),
          if (_scope.environment.searchLimit.isOverridden)
            // ★★ 上書きされているときだけ出す（決定 D64）★★
            //   常設すると、検証用の口が本番の設定に見える。
            _Section(
              title: '検索結果の上限（検証用）',
              children: [
                _Row(
                  label: 'いまの上限',
                  value: '${_scope.environment.searchLimit.limit} 件',
                ),
                Text(
                  '環境変数 $searchLimitEnvironmentKey で変更されています。'
                  'この口は検証用であり、本番の設定経路ではありません。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          _Section(
            title: '起動の内訳',
            children: [
              _Row(label: '段1 sqlite の確認', value: _ms(_scope.timings.sqlite)),
              _Row(label: '段2 DB を開く / 移行', value: _ms(_scope.timings.database)),
              _Row(label: '段3 取り込み', value: _ms(_scope.timings.import)),
              _Row(label: '段4 カタログの読み込み', value: _ms(_scope.timings.catalog)),
              _Row(label: '合計', value: _ms(_scope.timings.total)),
            ],
          ),
          if (_scope.environment.paths case final paths?)
            _Section(
              title: 'ファイルの置き場',
              children: [
                _Row(
                  label: 'データベース',
                  value: paths.databaseFile.path,
                  selectable: true,
                ),
                _Row(
                  label: '設定',
                  value: paths.settingsFile.path,
                  selectable: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _ms(Duration d) => '${d.inMilliseconds} ms';

/// 設定を変えても、効くのは次の起動から（決定 D56 / D60）。
class _RestartBanner extends StatelessWidget {
  const _RestartBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.restart_alt, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('保存しました。反映されるのは次の起動からです。'),
          ),
        ],
      ),
    );
  }
}

/// 取り込みが要るのかどうかを、実際の版を並べて言う。
class _UpdateHint extends StatelessWidget {
  const _UpdateHint({
    required this.local,
    required this.remote,
    required this.distMissing,
  });

  final int local;
  final int? remote;
  final bool distMissing;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch ((distMissing, remote)) {
      (true, _) => (
          Icons.error_outline,
          'カードデータが見つかりません。前回取り込んだ内容で動いています。',
        ),
      (false, final r?) when r > local => (
          Icons.download_outlined,
          '配信物のほうが新しい版です（$local → $r）。'
              'アプリを起動し直すと取り込みます。',
        ),
      _ => (Icons.check_circle_outline, '取り込み済みです。'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.candidate, required this.used});

  final DistCandidate candidate;
  final bool used;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              used ? Icons.check_circle : Icons.remove_circle_outline,
              size: 16,
              color: used ? null : Theme.of(context).disabledColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.source.label,
                      style: Theme.of(context).textTheme.bodyMedium),
                  SelectableText(
                    candidate.path,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: selectable
                  ? SelectableText(value)
                  : Text(value),
            ),
          ],
        ),
      );
}
