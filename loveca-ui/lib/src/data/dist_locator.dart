/// 配信物（dist）の場所を解決する（決定 D60 / `docs/UI設計メモ.md` §4-6(3)(4)）.
///
/// ★M1 の時点で設定画面（R6）はまだ無い。既定値だけで動く必要がある。
///
/// 解決順は 3 段。上から順に見て、**最初に「使える」と確かめられたもの**を採る。
///
/// | 順 | 出所 | 用途 |
/// |---:|---|---|
/// | 1 | 環境変数 `LOVECA_DIST_DIR` | 開発と検証 |
/// | 2 | `settings.json` の `distDir` | R6（M6）が書く。手でも置ける |
/// | 3 | 実行ファイルの隣の `data/dist/` | 配布形態（zip を展開して exe を実行） |
///
/// ★段 3 はデスクトップでしか成立しない（モバイルは実行ファイルの隣に置けない）。
/// モバイル実装は Phase 5 で足す（`docs/UI設計メモ.md` §5-5 の未決と同じ場所で決まる）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// dist の出所（＝解決順の段）。
///
/// ★★ 「どの段で解決したか」を値として持つ（M6 / R6）★★
/// 候補は条件つきで積まれる（環境変数も設定も空なら 1 件しか積まれない）ので、
/// **[DistLocation.searched] の件数からは段を復元できない。**
/// R6 が「いまどの段が効いているか」を出せるように、出所そのものを持たせる。
enum DistSource {
  /// 段 1: 環境変数 `LOVECA_DIST_DIR`。★開発と検証の口。
  environment,

  /// 段 2: `settings.json` の `distDir`。★R6 が書く本番の設定経路（決定 D60）。
  settings,

  /// 段 3: 実行ファイルの隣の `data/dist/`。★配布形態の既定。
  bundled;

  String get label => switch (this) {
        DistSource.environment => '環境変数 LOVECA_DIST_DIR',
        DistSource.settings => '設定（settings.json の distDir）',
        DistSource.bundled => '実行ファイルの隣の data/dist',
      };
}

/// 見に行った候補 1 件。
class DistCandidate {
  const DistCandidate({required this.source, required this.path});

  final DistSource source;
  final String path;
}

/// 探した結果。
///
/// ★★ 見つからなかったときに「どこを見たか」を必ず返す ★★
/// 3 段の解決順を持つ以上、**どこを見て無かったのかが出ないと利用者は直せない。**
class DistLocation {
  const DistLocation({
    required this.directory,
    required this.searched,
    this.source,
  });

  /// 使える dist。見つからなければ null。
  final Directory? directory;

  /// 実際に見た場所（順番どおり）。★見つかった場合も全部入れる。
  final List<DistCandidate> searched;

  /// 採用した段。★見つからなければ null。
  final DistSource? source;

  bool get found => directory != null;

  /// 既存の表示（起動失敗画面・`MasterImportOutcome`）はパスの列だけを使う。
  List<String> get searchedPaths => [for (final c in searched) c.path];
}

/// 探し方。★Phase 5 でモバイル実装を足す差し替え点。
abstract class DistLocator {
  Future<DistLocation> locate();
}

/// デスクトップ向けの 3 段解決。
class DesktopDistLocator implements DistLocator {
  DesktopDistLocator({
    required this.settingsDistDir,
    Map<String, String>? environment,
    String? executablePath,
  })  : _environment = environment ?? Platform.environment,
        _executablePath = executablePath ?? Platform.resolvedExecutable;

  /// `settings.json` の `distDir`。未設定なら null。
  final String? settingsDistDir;

  final Map<String, String> _environment;
  final String _executablePath;

  static const String environmentKey = 'LOVECA_DIST_DIR';

  @override
  Future<DistLocation> locate() async {
    final candidates = <DistCandidate>[
      if (_environment[environmentKey] case final v? when v.trim().isNotEmpty)
        DistCandidate(source: DistSource.environment, path: v.trim()),
      if (settingsDistDir case final v? when v.trim().isNotEmpty)
        DistCandidate(source: DistSource.settings, path: v.trim()),
      DistCandidate(
        source: DistSource.bundled,
        path: p.join(p.dirname(_executablePath), 'data', 'dist'),
      ),
    ];

    final searched = <DistCandidate>[];
    for (final candidate in candidates) {
      searched.add(candidate);
      if (isUsableDist(Directory(candidate.path))) {
        return DistLocation(
          directory: Directory(candidate.path),
          searched: searched,
          source: candidate.source,
        );
      }
    }
    return DistLocation(directory: null, searched: searched);
  }

  /// ★★ ディレクトリの有無だけでは足りない ★★
  /// `version.json` と `manifest.json` の存在まで確かめる。
  /// ここを緩めると、空のディレクトリを「見つかった」と扱って
  /// `MasterImporter` を呼んでしまい、**原因が「dist が無い」から
  /// 「読めない」に化ける**（決定 D60）。
  static bool isUsableDist(Directory dir) =>
      File(p.join(dir.path, 'version.json')).existsSync() &&
      File(p.join(dir.path, 'manifest.json')).existsSync();
}
