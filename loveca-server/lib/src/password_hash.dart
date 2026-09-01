/// パスワードの保存の形（決定 **D129-3** / **D129-5** / `docs/同期設計メモ.md` §44-7）。
///
/// ★★ これは §32-6 の 16（認証の口）ではない ★★
/// ★**口は 1 つも開いていない。**★ここに在るのは「★受け取った値を★★復元できない形に固める★★」
/// 部分だけである。★**16 が待っている 3 つ（**N-21** の (4) / **N-22** / **N-23**）を★1 つも要らない**
/// ことを 1 つずつ当てた（★§44-14）——
/// ★**何を送るか**は「届いた値を固める」だけなので効かない ／ ★**何に載せるか**は
/// 固めるのが受け取った★あとなので効かない ／ ★**識別子**は★★塩に混ぜない★★ので効かない。
///
/// ★**「空の器」ではない**（**D114-7** の理由 2 と混ぜない）—— ★書き込み点を待つ器ではなく、
/// ★★入力を受けて値を返す関数である★★（§32-6 の 11 / 12 / 13 と同じ形。★あれらも消費者 0 で置かれた）。
///
/// ---
///
/// ## ★★ なぜ PBKDF2-HMAC-SHA256 か（**D129-3**）★★
///
/// ★軸 5 つを宣言して候補 5 つを全欄埋めた（★正は §44-7）。★要点だけ ——
///
/// | 候補 | ★落ちた欄 |
/// |---|---|
/// | ★平文 | ★**元に戻す計算が在る**（★指示が「復元できない形にする」と書いている） |
/// | ★素のハッシュ 1 回 | ★**1 回試す費用がほぼ 0**（★作り置きの表が効く） |
/// | ★塩つきの速いハッシュ | ★**同上**（★★総当たりは「戻す計算」ではないが★同じ結果を出す★★） |
/// | ★**PBKDF2-HMAC-SHA256** | ★**落ちない**。★**依存が 1 つで済む**（`crypto` の `Hmac`） |
/// | ★scrypt / Argon2id | ★**落ちない**。★★記憶も要るぶん強い★★が、★**2 つ目の依存が要る** |
///
/// ★★**「Argon2id が劣る」とは書かない**★★ —— ★**到達する。★差は依存の数である**（**D115-2** が
/// 「増やしたこと自体を代償として記録する」と定めている）。
/// ★★**開き直す条件**★★: ★**記憶も要る鍵導出が★依存を増やさずに使えるようになったとき。**
/// ★そのときは [algorithm] の名前を見て段階的に移せる（★下の柵 1）。
///
/// ---
///
/// ## ★★ 柵 3 つ（**D129-5**）★★
///
/// | # | 柵 | ★なぜ |
/// |---|---|---|
/// | **1** | ★**繰り返し回数と塩を★保存した値の中に持つ** | ★**あとから回数を上げられる**。★持たないと★★全員に入れ直させないと上げられない★★ |
/// | **2** | ★**塩は `Random.secure()` から作る** | ★**D128-3** が生き残った分（★対象が鍵から塩へ入れ替わった）。★seed から決まる乱数だと★★塩が予測でき、作り置きの表が効く★★ |
/// | **3** | ★**照合は★時間の差が出ない比較にする** | ★先頭から比べて違ったところで止めると、★★合っている桁数が時間から漏れる★★ |
///
/// ★**`CLAUDE.md` §1 の「seed なし `Random()` を使わない」は `loveca_core` に対する制約である**
/// （§2 が `loveca_db` に同じ断りを書いている）。★**このパッケージには及ばない。**
/// ★それでも [newSalt] は乱数源を引数で受け取る —— ★**テストが値を固定できるようにするため**である
/// （★`loveca_core` の `DeterministicRng` と同じ理由で、★★同じ決定によるものではない★★）。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 保存した値の先頭に置く算法の名前。★**版そのものである**（★柵 1）。
const String passwordHashAlgorithm = 'pbkdf2-sha256';

/// 既定の繰り返し回数。
///
/// ★★ この値は「速さ」ではなく「遅さ」を買っている ★★
/// ★**1 回試すのに掛かる時間がそのまま★総当たりの費用になる。**
/// ★**実測は `docs/同期設計メモ.md` §45 に在る**（★数をここに書かない / **D-15**）。
///
/// ★★ あとから上げられる（★柵 1）★★
/// ★保存した値が★自分の回数を持つので、★**この定数を上げても★古い値は読める。**
/// ★★**下げてはならない**★★ —— ★下げても古い値は読めるが、★**新しい値だけが弱くなる。**
const int passwordHashIterations = 600000;

/// 塩の長さ（バイト）。
const int passwordSaltLength = 16;

/// 導出する鍵の長さ（バイト）。★SHA-256 の 1 ブロックぶん。
const int passwordHashLength = 32;

/// 保存した値の区切り。★base64 の字母に入らない文字を選ぶ。
const String _separator = r'$';

/// 新しい塩を作る。
///
/// ★★ [random] を渡さないと `Random.secure()` を使う（★柵 2）★★
/// ★**テストは値を固定するために渡す。**★`lib` から渡す口は今日 0 本である。
Uint8List newSalt({Random? random, int length = passwordSaltLength}) {
  final source = random ?? Random.secure();
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = source.nextInt(256);
  }
  return out;
}

/// PBKDF2（RFC 8018）—— ★PRF は HMAC-SHA256。
///
/// ★★ 自前で組み立てている理由 ★★
/// ★`crypto` は `Hmac` までしか持たない。★**PBKDF2 は★★公開された組み立て★★であり、
/// ★新しい原始関数を設計しているのではない。**
/// → ★★**golden を★別の実装で検算する**★★（★Python の `hashlib.pbkdf2_hmac` /
///   **D115-2** が内容ハッシュに採ったのと同じ作法）。★**正は `test/password_hash_test.dart`。**
Uint8List pbkdf2({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int length,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', '1 以上であること');
  }
  if (length < 1) {
    throw ArgumentError.value(length, 'length', '1 以上であること');
  }

  final hmac = Hmac(sha256, password);
  const hLen = 32;
  final blocks = (length + hLen - 1) ~/ hLen;
  final out = Uint8List(blocks * hLen);

  // ★ブロックの通し番号は 1 から。★4 バイトのビッグエンディアンで塩の後ろに置く。
  final seed = Uint8List(salt.length + 4);
  seed.setRange(0, salt.length, salt);

  for (var i = 1; i <= blocks; i++) {
    seed[salt.length] = (i >> 24) & 0xff;
    seed[salt.length + 1] = (i >> 16) & 0xff;
    seed[salt.length + 2] = (i >> 8) & 0xff;
    seed[salt.length + 3] = i & 0xff;

    var u = Uint8List.fromList(hmac.convert(seed).bytes);
    final t = Uint8List.fromList(u);
    for (var j = 1; j < iterations; j++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var k = 0; k < hLen; k++) {
        t[k] ^= u[k];
      }
    }
    out.setRange((i - 1) * hLen, i * hLen, t);
  }
  return Uint8List.sublistView(out, 0, length);
}

/// パスワードを★保存する形に固める。
///
/// ★返す形は `算法$回数$塩$値`（★塩と値は base64）。★**柵 1 がここに在る。**
String encodePasswordHash(
  String password, {
  required List<int> salt,
  int iterations = passwordHashIterations,
}) {
  final derived = pbkdf2(
    password: utf8.encode(password),
    salt: salt,
    iterations: iterations,
    length: passwordHashLength,
  );
  return [
    passwordHashAlgorithm,
    '$iterations',
    base64.encode(salt),
    base64.encode(derived),
  ].join(_separator);
}

/// 保存した値と照合する。★**合っていれば true。**
///
/// ★★ 壊れた値は false ではなく投げる ★★
/// ★**「合わない」と「読めない」を混ぜない。**
/// ★混ぜると、★DB が壊れたときに★★「全員のパスワードが違う」に化ける★★
/// （★`FormatException` なら気づける）。
bool verifyPassword(String password, String stored) {
  final parts = stored.split(_separator);
  if (parts.length != 4) {
    throw FormatException('★保存した値の形が違う（4 つに割れない）', stored);
  }
  if (parts[0] != passwordHashAlgorithm) {
    throw FormatException('★知らない算法: ${parts[0]}', stored);
  }
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) {
    throw FormatException('★繰り返し回数が読めない: ${parts[1]}', stored);
  }

  final Uint8List salt;
  final Uint8List expected;
  try {
    salt = base64.decode(parts[2]);
    expected = base64.decode(parts[3]);
  } on FormatException {
    throw FormatException('★塩か値が base64 として読めない', stored);
  }

  final actual = pbkdf2(
    password: utf8.encode(password),
    salt: salt,
    iterations: iterations,
    length: expected.length,
  );
  return constantTimeEquals(actual, expected);
}

/// 長さと中身を★時間の差が出ない形で比べる（★柵 3）。
///
/// ★★ 長さが違う場合も★早く帰らない ★★
/// ★早く帰ると★★値の長さが時間から漏れる★★。★長さの差は最後に畳み込む。
bool constantTimeEquals(List<int> a, List<int> b) {
  var diff = a.length ^ b.length;
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  // ★短いほうを読み切ったあとも、★長いほうの残りを畳み込む（★長さで分岐しない）。
  for (var i = n; i < a.length; i++) {
    diff |= a[i];
  }
  for (var i = n; i < b.length; i++) {
    diff |= b[i];
  }
  return diff == 0;
}
