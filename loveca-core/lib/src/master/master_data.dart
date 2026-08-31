/// 配信マスタデータのパースと更新計画.
///
/// 設計書 STEP 10 §10.2 / §10.3 に対応。
///
/// 配信物の構成:
///   version.json          最小・毎回取得
///   manifest.json         全ファイルのパスとハッシュ
///   cards/{EXPANSION}.json 商品単位。一度公開したら基本的に不変
///   meta/products.json
///   meta/faqs.json
///   meta/ruleConfig.json
///   images/{size}/{imageHash}.webp
///
/// ★★ ここには「この名前は中身を指すので不変」という趣旨の一文があった。
/// 誤りだったので消した（2026-08-27）★★
/// `imageHash` は**原本 PNG のハッシュ**であり、配信 WebP の中身を名指せていない。
/// → 決定 D-4 / D-33（`ルール整合性チェック_v1.06.md`）。
/// ★消した一文の実物と、なぜ誤りかは D-33 に在る。
/// ★★ 実物をここに書き戻さないこと ★★ —— D-33 の検査は
/// 「その一文がこのファイルに 0 件であること」で見る（D-30 の (a)）。
///
/// ★商品単位に分割してある理由★
/// 新弾が出ても既存ファイルのハッシュが変わらないため、
/// 差分更新が「ハッシュが違うファイルだけ取る」で成立する。
library;

import 'dart:convert';

import '../entities/card.dart';
import '../entities/deck.dart';
import '../entities/product.dart';

/// version.json
class VersionInfo {
  const VersionInfo({
    required this.dataVersion,
    required this.minAppVersion,
    required this.manifestPath,
    required this.manifestHash,
  });

  final int dataVersion;

  /// これ未満のアプリは強制アップデートを促す。
  final String minAppVersion;
  final String manifestPath;
  final String manifestHash;

  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        dataVersion: json['dataVersion'] as int,
        minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
        manifestPath: json['manifestPath'] as String? ?? '/data/manifest.json',
        manifestHash: json['manifestHash'] as String? ?? '',
      );

  static VersionInfo parse(String source) =>
      VersionInfo.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// [appVersion] がマスタデータの要求バージョンを満たすか。
  bool isAppSupported(String appVersion) =>
      compareVersions(appVersion, minAppVersion) >= 0;
}

/// "1.2.10" 形式の比較。a < b なら負、等しければ 0、a > b なら正。
int compareVersions(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// manifest.json の 1 エントリ。
class ManifestFile {
  const ManifestFile({
    required this.path,
    required this.hash,
    this.bytes = 0,
    this.cardCount = 0,
  });

  final String path;

  /// "sha256:..." 形式。
  final String hash;
  final int bytes;
  final int cardCount;

  factory ManifestFile.fromJson(Map<String, dynamic> json) => ManifestFile(
        path: json['path'] as String,
        hash: json['hash'] as String? ?? '',
        bytes: json['bytes'] as int? ?? 0,
        cardCount: json['cardCount'] as int? ?? 0,
      );
}

/// manifest.json
class Manifest {
  const Manifest({required this.dataVersion, required this.files});

  final int dataVersion;
  final List<ManifestFile> files;

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
        dataVersion: json['dataVersion'] as int,
        files: (json['files'] as List? ?? [])
            .map((e) => ManifestFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static Manifest parse(String source) =>
      Manifest.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, ManifestFile> get byPath => {for (final f in files) f.path: f};

  int get totalBytes => files.fold(0, (sum, f) => sum + f.bytes);
}

/// cards/{EXPANSION}.json
class CardSet {
  const CardSet({
    required this.expansion,
    required this.cards,
    required this.printings,
  });

  final String expansion;
  final List<Card> cards;
  final List<Printing> printings;

  factory CardSet.fromJson(Map<String, dynamic> json) => CardSet(
        expansion: json['expansion'] as String? ?? '',
        cards: (json['cards'] as List? ?? [])
            .map((e) => Card.fromJson(e as Map<String, dynamic>))
            .toList(),
        printings: (json['printings'] as List? ?? [])
            .map((e) => Printing.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static CardSet parse(String source) =>
      CardSet.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// meta/*.json のパース。
class MasterMeta {
  static List<Product> parseProducts(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return (json['products'] as List? ?? [])
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Faq> parseFaqs(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return (json['faqs'] as List? ?? [])
        .map((e) => Faq.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static RuleConfig parseRuleConfig(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    int v(String key, int fallback) => json[key] as int? ?? fallback;
    return RuleConfig(
      mainDeckSize: v('mainDeckSize', 60),
      memberCount: v('memberCount', 48),
      liveCount: v('liveCount', 12),
      energyDeckSize: v('energyDeckSize', 12),
      maxCopiesPerCardNumber: v('maxCopiesPerCardNumber', 4),
      initialHandSize: v('initialHandSize', 6),
      initialEnergyOnField: v('initialEnergyOnField', 3),
      liveSlotMax: v('liveSlotMax', 3),
      winCondition: v('winCondition', 3),
      stageAreaCount: v('stageAreaCount', 3),
    );
  }
}

/// 更新の判定結果。
enum UpdateDecision {
  /// 更新不要。
  ///
  /// ★★ 決定 D118-3（版-3）以降、この値が返るのは**降格のときだけ**である ★★
  ///   配信物の dataVersion が取り込み済みより**小さい**場合。
  ///   ★同値では返らない —— 同じ版でも中身が違えば取り込む（所見 D-32）。
  ///   ★名前は変えていない。変えると `loveca_db` / `loveca-ui` の分岐まで
  ///     動き、**1 コミット = 1 論点**（CLAUDE.md §7-4）から外れる。
  upToDate,

  /// 差分更新を行う。
  update,

  /// アプリが古すぎる。強制アップデートを促す。
  appTooOld,
}

/// 更新計画。
class UpdatePlan {
  const UpdatePlan({
    required this.decision,
    this.filesToDownload = const [],
    this.filesToDelete = const [],
    this.totalBytes = 0,
    this.fromVersion = 0,
    this.toVersion = 0,
  });

  final UpdateDecision decision;

  /// 取得が必要なファイル (ハッシュが違う、または新規)。
  final List<ManifestFile> filesToDownload;

  /// 配信側から消えたファイル。
  final List<String> filesToDelete;

  final int totalBytes;
  final int fromVersion;
  final int toVersion;

  bool get needsDownload => filesToDownload.isNotEmpty;
}

/// 差分更新の計画を立てる。
///
/// ★ネットワークアクセスは行わない純粋関数★
/// 取得済みの version / manifest と、ローカルの状態から何をすべきかだけを決める。
/// テストしやすさのために副作用を持たせない。
UpdatePlan planUpdate({
  required VersionInfo remoteVersion,
  required Manifest remoteManifest,
  required String appVersion,
  required int localDataVersion,

  /// ローカルに保持しているファイルのハッシュ (path -> "sha256:...")。
  Map<String, String> localFileHashes = const {},
}) {
  if (!remoteVersion.isAppSupported(appVersion)) {
    return UpdatePlan(
      decision: UpdateDecision.appTooOld,
      fromVersion: localDataVersion,
      toVersion: remoteVersion.dataVersion,
    );
  }

  // ★★ 版ゲートは「より小さい」で切る (決定 D118-3 = 版-3 / 所見 D-32) ★★
  //   ★同値は通す —— 同じ dataVersion のまま cards/*.json を作り直しても
  //     取り込まれる。ここが `<=` だった間は、直したカードデータが
  //     **1 ファイルも見られずに** 落ちていた (D-32)。
  //   ★降格は止める —— remote のほうが古いときは今までどおり `upToDate`。
  //     ★★これは副作用ではなく意図である★★ (決定 D118-3 の読み B)。
  //     根拠: 通すと古い dist が取り込まれ、下の削除計画
  //     (remote の manifest に無いローカルの path) が
  //     **新しい商品ファイルを消す**。
  //
  // ★同値で通したあとに何が起きるかは下のハッシュ比較が決める。
  //   中身が同じなら `filesToDownload` も `filesToDelete` も空になり、
  //   決定は `update` だが取るものは無い。★`upToDate` には戻さない
  //   —— 「版で切った」と「中身が同じだった」は別の事実である。
  if (remoteVersion.dataVersion < localDataVersion) {
    return UpdatePlan(
      decision: UpdateDecision.upToDate,
      fromVersion: localDataVersion,
      toVersion: remoteVersion.dataVersion,
    );
  }

  final toDownload = <ManifestFile>[];
  for (final file in remoteManifest.files) {
    final localHash = localFileHashes[file.path];
    if (localHash == null || localHash != file.hash) {
      toDownload.add(file);
    }
  }

  final remotePaths = remoteManifest.byPath.keys.toSet();
  final toDelete = localFileHashes.keys
      .where((path) => !remotePaths.contains(path))
      .toList()
    ..sort();

  return UpdatePlan(
    decision: UpdateDecision.update,
    filesToDownload: toDownload,
    filesToDelete: toDelete,
    totalBytes: toDownload.fold(0, (sum, f) => sum + f.bytes),
    fromVersion: localDataVersion,
    toVersion: remoteVersion.dataVersion,
  );
}

/// 画像 URL を組み立てる。
///
/// ★★ ここには「この名前は中身を指すので不変。だから差し替え時に
/// キャッシュを無効化する問題が構造的に起きない」という趣旨の 2 文があった。
/// 誤りだったので消した（2026-08-27）★★
/// `imageHash` は**原本 PNG のハッシュ**であり、配信 WebP の中身を名指せていない。
/// → 決定 D-4 / D-33（`ルール整合性チェック_v1.06.md`）。
/// ★どう直すか（D-4 の案）はまだ決まっていない。★訂正と判断は別である。
/// ★★ 実物をここに書き戻さないこと ★★（上の library doc と同じ理由 / D-30 の (a)）。
///
/// (公式サイトの picture パスとは別物。あちらは規則が破綻しており組み立て禁止)
String imageUrl(String cdnBase, String imageHash, ImageSize size) =>
    '$cdnBase/images/${size.name}/$imageHash.webp';

enum ImageSize {
  /// 一覧用。幅 200px。全件取得しても 37MB 程度。
  thumb,

  /// デッキ編集・盤面用。幅 500px。
  normal,

  /// カード詳細・拡大用。幅 1000px。
  large,
}
