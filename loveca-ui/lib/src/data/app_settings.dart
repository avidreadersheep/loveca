/// 設定の永続化（決定 D60 / `docs/UI設計メモ.md` §4-6(5)）.
///
/// ★`shared_preferences` を採らない。
/// 器がプラットフォームごとに 3 通りに分かれる（Windows は JSON /
/// Android は SharedPreferences / iOS は NSUserDefaults）。
/// **現時点で 2 項目のためにその代償を払う理由が無い。**
///
/// ★見直す条件: 項目が **10 を超える**、または型付きの構造（入れ子・配列）が
/// 要るようになったとき。
library;

import 'dart:convert';
import 'dart:io';

/// 保存される設定。
class AppSettings {
  const AppSettings({this.distDir, this.showParallel = true});

  /// dist の場所（解決順の段 2 / `DistLocator`）。
  final String? distDir;

  /// 一覧のパラレル表示の既定（CLAUDE.md §5-(4)）。
  final bool showParallel;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({String? distDir, bool? showParallel}) => AppSettings(
        distDir: distDir ?? this.distDir,
        showParallel: showParallel ?? this.showParallel,
      );

  Map<String, dynamic> toJson() => {
        if (distDir != null) 'distDir': distDir,
        'showParallel': showParallel,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        distDir: json['distDir'] as String?,
        showParallel: json['showParallel'] as bool? ?? true,
      );
}

/// 読み込み結果。
///
/// ★★ 壊れていたら既定に戻したうえで警告を出す ★★
/// 黙って既定に戻すと「設定したのに効かない」が原因不明のまま残る。
/// そのため「既定に戻した理由」を戻り値に載せる。
class AppSettingsLoad {
  const AppSettingsLoad(this.settings, {this.recoveredFrom});

  final AppSettings settings;

  /// 既定に戻した場合の理由。正常なら null。
  final Object? recoveredFrom;

  bool get wasRecovered => recoveredFrom != null;
}

class AppSettingsStore {
  const AppSettingsStore(this.file);

  final File file;

  /// ★存在しないのは異常ではない（初回起動）。既定を返し、警告も出さない。
  Future<AppSettingsLoad> load() async {
    if (!file.existsSync()) {
      return const AppSettingsLoad(AppSettings.defaults);
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) {
        throw FormatException('設定の最上位が Map ではありません: ${json.runtimeType}');
      }
      return AppSettingsLoad(AppSettings.fromJson(json));
    } on Object catch (error) {
      // ★黙って既定に戻さない。理由を持ち帰る。
      return AppSettingsLoad(AppSettings.defaults, recoveredFrom: error);
    }
  }

  /// ★一時ファイルへ書いてから rename する。
  /// 途中で落ちても、壊れた設定ファイルが残らない。
  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
