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

/// ★★ エネルギーデッキ 0 枚のときに補うカードの既定（決定 D97）★★
///
/// ★★ 根拠は「利用者が指定した」である ★★
/// 総合ルール 6.1.1.3 が縛るのは**種別と枚数**（エネルギーカード 12 枚ちょうど）で、
/// **どのカードかは縛っていない。**実データでもエネルギー 567 種は
/// 全フィールドが一様に空で、**ゲーム上の差が 1 件も無い**（差は絵と名前だけ）。
/// → **条文にも実データにも根拠は無い。だから利用者が決めた**（2026-08-26）。
/// ★`D-B` が禁じているのは「根拠のない数値・条件」であって、
/// **利用者が決めた値ではない。**「根拠が無い」と読まないこと。
///
/// ★★ ハードコードだが固定ではない ★★
/// 利用者が R6（設定）と盤面の開始ダイアログのどちらでも変えられる。
/// **変えたければコードを直す必要は無い。**
///
/// ★★ cardNumber ではなく printingId である ★★
/// `LL-E-002` は非パラレル刷りが 2 件あり（`-SD` と `-PR`）、
/// **決定 D68 が「既定がコイントス」として開示対象にした 19 種の 1 つ**である。
/// cardNumber では刷りが決まらず、2 刷りは `imageHash` が違う = **絵柄が別物**。
/// → printingId で持てば推論が発生せず、曖昧さがそもそも生じない。
///
/// ★★ 本番コードでカード番号を書いてよい唯一の場所である ★★
/// D97 以前は 3 パッケージの `lib/` に 0 件だった。**ここが 1 箇所目で、例外はこれだけ。**
/// 増えないことは `test/data/card_number_literal_test.dart` が機械で見張る。
const String kDefaultEnergyFillPrintingId = 'LL-E-002-SD';

/// 保存される設定。
class AppSettings {
  const AppSettings({
    this.distDir,
    this.showParallel = true,
    this.energyFillPrintingId = kDefaultEnergyFillPrintingId,
  });

  /// dist の場所（解決順の段 2 / `DistLocator`）。
  final String? distDir;

  /// 一覧のパラレル表示の既定（CLAUDE.md §5-(4)）。
  final bool showParallel;

  /// エネルギーデッキ 0 枚のときに 12 枚として補う刷り（決定 D97）。
  ///
  /// ★`null` は「補わない」を意味する。★**0 枚のまま盤面を開始できる**
  /// （6.1 違反では止めない / **D81** / **D-A**）ので、これは異常ではない。
  final String? energyFillPrintingId;

  static const AppSettings defaults = AppSettings();

  /// ★★ [clearDistDir] が要る理由 ★★
  /// `distDir ?? this.distDir` だけだと **設定を消す手段が無い。**
  /// R6（M6）は「段 2 をやめて段 3 の既定に戻す」を出すので、
  /// 消す口が無いと片道になる。`CardListFilter.copyWith` の
  /// `clearExpansion` と同じ流儀に揃えてある。
  AppSettings copyWith({
    String? distDir,
    bool clearDistDir = false,
    bool? showParallel,
    String? energyFillPrintingId,
    bool clearEnergyFill = false,
  }) =>
      AppSettings(
        distDir: clearDistDir ? null : (distDir ?? this.distDir),
        showParallel: showParallel ?? this.showParallel,
        energyFillPrintingId: clearEnergyFill
            ? null
            : (energyFillPrintingId ?? this.energyFillPrintingId),
      );

  /// ★★ `energyFillPrintingId` は null でも書く ★★
  /// `distDir` と流儀が違うのは、**既定が null ではない**からである。
  /// キーごと省くと、読み戻したとき「利用者が補完をやめた」と
  /// 「初回でキーがまだ無い」が**区別できず、既定に戻ってしまう。**
  Map<String, dynamic> toJson() => {
        if (distDir != null) 'distDir': distDir,
        'showParallel': showParallel,
        'energyFillPrintingId': energyFillPrintingId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        distDir: json['distDir'] as String?,
        showParallel: json['showParallel'] as bool? ?? true,
        // ★キーの有無で分ける（上の toJson の注記を参照）。
        energyFillPrintingId: json.containsKey('energyFillPrintingId')
            ? json['energyFillPrintingId'] as String?
            : kDefaultEnergyFillPrintingId,
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
