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

/// 探した結果。
///
/// ★★ 見つからなかったときに「どこを見たか」を必ず返す ★★
/// 3 段の解決順を持つ以上、**どこを見て無かったのかが出ないと利用者は直せない。**
class DistLocation {
  const DistLocation({required this.directory, required this.searched});

  /// 使える dist。見つからなければ null。
  final Directory? directory;

  /// 実際に見た場所（順番どおり）。★見つかった場合も全部入れる。
  final List<String> searched;

  bool get found => directory != null;
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
    final candidates = <String>[
      if (_environment[environmentKey] case final v? when v.trim().isNotEmpty)
        v.trim(),
      if (settingsDistDir case final v? when v.trim().isNotEmpty) v.trim(),
      p.join(p.dirname(_executablePath), 'data', 'dist'),
    ];

    final searched = <String>[];
    for (final candidate in candidates) {
      searched.add(candidate);
      if (isUsableDist(Directory(candidate))) {
        return DistLocation(
          directory: Directory(candidate),
          searched: searched,
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
