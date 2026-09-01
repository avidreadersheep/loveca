/// ★★ 配信物を★取りに行く手段 —— ★§32-6 の **8** の 4 番目（**D137-6**）★★
///
/// ★★ 口だけである。★呼ぶ側は 1 行も無い ★★
/// ★**いつ取りに行くか / ★どう見せるかは★★この口の外である★★**
/// （★★モバイルの UI の形である★★ / **D137-6** —— ★運転指示【3】「UI は差し込み口まで」）。
/// ★**16 / 18 / 21 の口と★同じ形を採った**（**D131-3** / **D132-4**）。
///
/// ---
///
/// ## ★★ D43 を踏まない —— ★★読む経路は 1 本のままである（**D137-1** ＝ 画経-4）★★
///
/// ★**D43** が禁じたのは「★経路が 2 つあると★★どちらから来た画像かで切り分けができなくなる★★」ことである。
/// ★★**この口は★★取り込みの側★★であって、★★読む側ではない★★。**★★
/// ★**読むのは今日どおり `CardImageSource` の 1 本**（★`LocalDirectoryCardImageSource`）——
/// ★**この口が埋めるのは★★そのディレクトリの中身★★である。**
/// → ★★**読む実装は 1 本のまま。★D43 の害は起きない**★★（**D137-3**）。
///
/// ★★**D43 の期限も切れている**★★ —— ★**あちらは「Phase 4 で配信経路が固まるまで」と★自ら書いており、
/// ★★固まった★★**（**D120-1** ＝ ★置き場 ／ **D121-1** ＝ ★差分の単位 ／ **D130-7** ＝ ★パスで分ける）。
/// ★★**「期限が切れたから何でもよい」とは書かない**★★ —— ★**上の 1 本という形が★理由である。**
///
/// ## ★★ 何を渡されるか（★★呼び出し側が決める★★）★★
///
/// | 何 | ★なぜ呼び出し側か |
/// |---|---|
/// | `HttpClient` | ★**証明書の信頼をどう組むかは★この口の外**（**D131-3** と同じ形 / ★**N-24** の (2)） |
/// | `Uri` | ★**サーバーの住所は★設定である**（★★画面の仕事★★ / **D132-6** と同じ形） |
///
/// ★★**`AppSettings` に足さない**★★ —— ★**それは画面の仕事である**（★**D132-6** の断りをそのまま採る）。
///
/// ## ★★ 投げる。★答えを分けない（★★16 / 18 / 21 とは形が違う★★）★★
///
/// ★**`MasterFileSource` の契約が「読めなければ投げる」である**（★実読 ——
/// ★`LocalDirectoryMasterFileSource` は `FileSystemException` を投げ、
/// ★`MapMasterFileSource` は `StateError` を投げる）。
/// ★★**`MasterImporter` は★ファイルごとに `on Object catch` で受けて★1 件ずつ記録する**★★（★実読）。
/// → ★★**ここで答えを 3 つに分けると、★取り込み層が★★それを 1 つも見ない★★。**★★
/// → ★**投げる側に合わせる。★★選んだのではない。★契約がそうなっている★★。**
///
/// ## ★★ 名乗らない（**D133-7**）★★
///
/// ★**配信は★アカウント無しでも使える**。→ ★**資格情報を 1 バイトも送らない**（★対で固定した）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_db/loveca_db.dart';

/// 配信物を配るパスの前置（★サーバー側の `distPathPrefix` と★★同じ字面★★）。
///
/// ★★ やり取りの形が★2 か所に書かれる ★★
/// ★**D126-3**（★通信は HTTP 越しであってコード依存ではない）が★★買った代償である★★。
/// → ★**走査で見張る**（★`loveca-ui/test/data/http_master_file_source_test.dart`）。
const String distPathPrefix = '/dist/';

/// 取りに行けなかった。
///
/// ★★ 理由を★字面で持つ（★★状態コードを畳まない★★）★★
/// ★**取り込み層は★1 件ずつ記録するので、★★何が起きたかが読めないと直せない★★。**
class MasterFetchException implements Exception {
  const MasterFetchException(this.path, this.reason);

  /// 配信物の中の相対パス。
  final String path;

  /// 何が起きたか（★状態コード、または通信の失敗の理由）。
  final String reason;

  @override
  String toString() => 'MasterFetchException($path): $reason';
}

/// HTTP 越しに配信物を取りに行く。
class HttpMasterFileSource implements MasterFileSource {
  HttpMasterFileSource({required this.client, required this.server});

  /// ★証明書の信頼は★呼び出し側が組む（**D131-3** と同じ形）。
  final HttpClient client;

  /// ★サーバーの住所。★**パスは使わない**（★★下で差し替える★★）。
  final Uri server;

  /// 実際に読まれた path。★差分更新の確認に使う（★他の実装と同じ）。
  final List<String> readPaths = [];

  @override
  Future<String> read(String path) async => utf8.decode(await readBytes(path));

  @override
  Future<List<int>> readBytes(String path) async {
    readPaths.add(path);

    final HttpClientResponse response;
    try {
      final request =
          await client.getUrl(server.replace(path: '$distPathPrefix$path'));
      response = await request.close();
    } on Object catch (error) {
      // ★★ つながらない —— ★状態コードが無い ★★
      throw MasterFetchException(path, '$error');
    }

    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw MasterFetchException(path, 'status ${response.statusCode}');
    }

    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
