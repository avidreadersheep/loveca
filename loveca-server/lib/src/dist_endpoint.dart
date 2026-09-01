/// ★★ 配信物を配る口 —— ★★カードマスタの配信（決定 **D120-1** / **D130-7** / **D133-7**）★★
///
/// ★★ この口は★名乗りを要求しない ★★
/// ★**配信は★誰でも受け取れる**（**D133-7** —— ★★アカウント無しでもカードマスタの取り込みが使える★★）。
/// ★**D130-7** が「★配信と同じ口を★パスで分ける」と定めている。
///
/// ★★【要確認/法務】ここが「★カードのデータと画像が★他人の機械経由で渡る★最初の瞬間」である ★★
/// ★★**動かす前に **D104** の札を引き直すかを★利用者が判断すること**★★（**D133-5** と同じ形 —— ★**書く前ではない**）。
/// ★**引き金は★これで 4 つ目になる**（★§35-6 のデッキ ／ ★§50-10 のパスワード ／ ★**D133-4** の「誰でも作れる」／ ★★ここ★★）。
/// ★★**2026-09-02 訂正: ★「4 つ目」は★★列を取り違えている★★**★★（★上の行は 1 文字も書き換えない / **D-35**）——
/// ★**前の 3 つは★★利用者自身の物★★が★確認の範囲を超えるかを問う**（★**D104** の依存 2）。
/// ★★**ここは★第三者が権利を持つ物を★他人の機械から配ってよいかを問う**★★（★**D104** の「何が解けたか」の Phase 0-5 の行）。
/// → ★★**別の列の 1 つ目である**★★（★★列 乙 ＝ 著作の列★★ / `docs/同期設計メモ.md` §61）。
/// ★★**この口が★最も早い引き金である**★★ —— ★**名乗りを要求しないので、★★アカウントが 1 つも無くても配れる★★**（★§61-7）。
/// ★★**「D120-1 が既に決めている」と★札を消さないこと**★★ —— ★**D120-1 は★置き場を決めたのであって、
/// ★★確認の範囲を 1 文字も述べていない★★**（**D124-4** と同じ形）。
///
/// ---
///
/// ## ★★ 呼ばれる回数の上限を★掛けていない（★守っていない。★隠さない）★★
///
/// ★**上限（**N-26** の既定値）は★★他の 5 つのパスには効いている★★**（`auth_endpoint.dart`）。
/// ★★**この口だけ★対象から外した。★理由は 1 つである**★★ ——
/// ★**この口は★★名乗りを 1 度も見ない★★ので、★★固める処理（1.5 秒）を 1 度も通らない★★**。
/// → ★**上限を立てた理由（★§54-2 の実測）が★この口には当たらない。**
///
/// ★★**「安全である」とは書かない**★★ —— ★**押し続けられれば★★ファイルを読む費用は掛かる★★**（★測っていない / **D-28**）。
/// ★★**これは **N-27**（門 ソ）の★★入力である★★**★★ —— ★**論点 (2)「口ごとに枠を分けるか」に★1 行足した。**
///
/// ★★**2026-09-02: ★測った。★上限が何を守っているかが★はっきりした**★★（`docs/同期設計メモ.md` §62）——
/// ★**名乗る 1 回 ＝ ★★1522 ms★★ ／ ★配る 1 回（★配信物で最も大きい 344,142 B のファイル）＝ ★★0.261 ms★★**
/// （★★2026-09-02 実測 / ★この機械 / ★本番の回数 600000★★）。→ ★**比は約 5,831 倍。**
/// ★**配信物を丸ごと 1 回取り込んでも★約 2.0 秒で、★★名乗る 2 回（3.0 秒）に届かない★★**（★算術）。
/// → ★★**外しても★上限は★5 つのパスの固める処理を守っている。★門ではない**★★（★相談役の判定条件）。
/// ★★**それでも「安全である」とは書かない**★★ —— ★**測っていない軸が 3 つ在る**（★§62-7）。
///
/// ## ★★ 柵 —— ★★受け取った字面を★そのまま繋がない（**D134-7** と同じ型）★★
///
/// ★**呼ぶ側は★パスを自由に決められる**（★誰でも呼べる）。
/// → ★**そのまま繋ぐと★★配信物の外のファイルを読ませられる★★。**
/// → ★**段を 2 つ置く**（★下の [DistFileStore]）——
///   ★**(1) 区切りごとに見て、★`.` / `..` / 空 / 区切り記号を含むものを断る**
///   ★**(2) 繋いだ結果が★★根の下に在ることを確かめる★★**（★手当てを 2 つ重ねる）。
///
/// ★★**2026-09-02 訂正: ここには「`Uri.path` は★復号済みで渡る」と書いてあった。★★偽である★★**★★
/// （★型は **D-15 (j)** —— ★★検証していない断定。★対が落ちて分かった★★）——
/// ★**`Uri.path` は★★符号化されたまま★★返る**（★実測 2026-09-02: 日本語の名前が `%E7%A7%98%E5%AF%86.txt` になる）。
/// → ★**そのまま繋ぐと★★日本語の名前のファイルが 1 つも読めない★★。**
/// → ★★**`Uri.pathSegments` を使う**★★（★★こちらは復号済みで、★区切りごとに分かれている★★ / ★実測）。
///
/// ★★**あわせて分かったこと —— ★`Uri.parse` は★上へ抜ける段を★自分で畳む**★★（★実測 2026-09-02）——
/// ★`/dist/../x` も `/dist/%2e%2e/x` も★★`Uri.parse` の時点で `/x` になる★★。
/// → ★**素の `HttpClient` からは★★この柵に 1 度も届かない★★**（★★だから素の口で当てる★★ / ★試験を見ること）。
///
/// ## ★★ 中身を 1 バイトも見ない（**D105-2** と同じ精神）★★
///
/// ★**バイト列のまま返す。★`loveca_core` を 1 つも呼ばない**（★線 α は空のまま / **D115-6**）。
/// ★★**返す型は 1 つだけ**★★（`application/octet-stream`）—— ★**拡張子で分けない。**
/// ★**理由**: ★★呼ぶ側（`MasterFileSource`）は★型を 1 度も見ない★★（★★実読★★）。
/// → ★**決めていない分岐を先に置かない**（**D114-7** の理由 2）。★**要ると分かったら足す。**
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// 配信物を配るパスの前置。
///
/// ★**`/dist/version.json` のように★続きを相対パスとして読む。**
/// ★★**振り分けは★前置での一致である**★★（★他の 5 つは★★完全一致★★）——
/// ★**配信物は★★ファイルが 7,581 件在る★★**（★2026-08-27 実測 / `docs/同期設計メモ.md` §10 の **N-2**）ので、
/// ★**1 件ずつパスを書けない。**
/// ★★**それでも `/decks` などに吸われない**★★ —— ★**前置が違う**（★対で固定した）。
const String distPathPrefix = '/dist/';

/// 上の前置の★段としての形（★振り分けは★★復号済みの段で見る★★）。
const String distPathSegment = 'dist';

/// 配信物の読み出し（★★置き場は呼び出し側が渡す★★ / **D131-5** の柵 3 と同じ形）。
class DistFileStore {
  const DistFileStore(this.root);

  /// 配信物の根（`dist/`）。
  final Directory root;

  /// [relativePath] を読む。★★読めなければ `null`★★。
  ///
  /// ★★ 「無い」と「外を指している」を★区別しない ★★
  /// ★**区別すると★★根の外に何が在るかを教えることになる★★**
  /// （★**D130** の柵「利用者名の存在を漏らさない」と★同じ形）。
  ///
  /// ★[segments] は★★復号済みの段★★（`Uri.pathSegments` がそのまま渡る）。
  List<int>? read(List<String> segments) {
    if (!isSafeSegments(segments)) return null;

    final rootPath = p.normalize(root.absolute.path);
    final file = File(p.joinAll(<String>[rootPath, ...segments]));
    final resolved = p.normalize(file.absolute.path);

    // ★★ 段 2 —— ★繋いだ結果が★根の下に在ること（★手当てを 2 つ重ねる）★★
    if (!p.isWithin(rootPath, resolved)) return null;
    if (!file.existsSync()) return null;

    return file.readAsBytesSync();
  }

  /// ★段 1 —— ★区切りごとに見る。
  ///
  /// ★★ 断るもの（★★1 つずつ対で固定した★★）★★
  /// ★段が 0 個 ／ ★空の段 ／ ★`.` ／ ★`..` ／ ★区切り記号を含む段 ／ ★ドライブ（`:` を含む段）。
  static bool isSafeSegments(List<String> segments) {
    if (segments.isEmpty) return false;
    for (final s in segments) {
      if (s.isEmpty || s == '.' || s == '..') return false;
      if (s.contains(':')) return false;
      if (s.contains('/')) return false;
      if (s.contains(String.fromCharCode(92))) return false;
    }
    return true;
  }
}

/// 配る口に 1 つ答える（★待ち受けを知らない）。
///
/// ★★ 名乗りを 1 度も見ない ★★
Future<void> handleDistRequest(HttpRequest request, DistFileStore dist) async {
  if (request.method != 'GET') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }

  // ★★ 復号済みの段で見る（★上の doc の訂正）★★
  final segments = request.uri.pathSegments;
  if (segments.isEmpty || segments.first != distPathSegment) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  final bytes = dist.read(segments.sublist(1));
  if (bytes == null) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.binary
    ..add(bytes);
  await request.response.close();
}
