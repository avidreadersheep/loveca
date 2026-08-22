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
///   images/{size}/{imageHash}.webp   コンテンツハッシュ命名 = 不変
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

  if (remoteVersion.dataVersion <= localDataVersion) {
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
/// ★画像はコンテンツハッシュ命名なので不変★
/// CDN の immutable キャッシュが使え、差し替え時の無効化問題が構造的に起きない。
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
