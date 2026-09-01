/// アカウントの保管 —— ★★JSON のファイル 1 つ★★（決定 **D131-4** / **D131-5** /
/// `docs/同期設計メモ.md` §48-4 〜 §48-6）。
///
/// ★★ なぜファイルか（★軸 6 つで候補 5 つを全欄埋めた / §48-4）★★
///
/// | 候補 | ★落ちた欄 |
/// |---|---|
/// | ★メモリだけ | ★**サーバーが落ちるとアカウントが消える**（★「選ぶ余地が無い」側） |
/// | ★アカウントごとに 1 ファイル | ★**利用者名がファイル名になり、★★使える文字を先に決めてしまう★★**（★規則は未決 / §46-14 の 2） |
/// | ★`loveca_db`（drift ＋ SQLite） | ★**落ちない。★依存が増え、★**D126-4** の 3 段目が動く**。★★もう 1 つ理由が在る★★ —— ★下 |
/// | ★★**JSON のファイル 1 つ**★★ | ★**落ちない** |
///
/// ★★ `loveca_db` を採らない★もう 1 つの理由（★§48-5）★★
/// ★`loveca_db` の `schemaVersion` は★★クライアントの DB の版である★★。
/// → ★**サーバーが同じパッケージを使うと、★★端末の移行とサーバーの移行が★同じ番号を共有する★★。**
/// → ★**片方の都合で版が上がると、★もう片方が★★理由の無い移行を走らせる★★。**
/// ★★**「劣る」とは書かない**★★ —— ★**利用者が増えたときは★そちらのほうが強い**（★索引が要る規模）。
/// ★★**開き直す条件**★★: ★**1 つのファイルが重くなったとき**（★**測っていない** / **D-28**）。
///
/// ★★ 仮定を 1 行で書く（**D-25** の作法）★★
/// ★★**このファイルを触るのは★1 つのプロセスだけである。**★★
/// ★根拠は **D130-6**（★サーバーが待つ ＝ 待ち受けるのは 1 つ）。
/// ★**2 つ以上のプロセスが同じファイルを触る形は★★守っていない★★**（★破る経路は今日 0 本）。
///
/// ★★ 柵 3 つ（決定 **D131-5**）★★
///
/// | # | 柵 | ★なぜ |
/// |---|---|---|
/// | **1** | ★**書き込みは★一時ファイルへ書いてから置き換える** | ★**途中で落ちると★★全アカウントが消える★★**（★1 つのファイルに全部在る） |
/// | **2** | ★**重複は断る** | ★**D130-9**（★サーバーが一意性を保つ）の★★実装の場所がここである★★ |
/// | **3** | ★**置き場は★呼び出し側が渡す** | ★**先例は **D59** と `loveca_db` の `native.dart`**（★「置き場所は呼び出し側が決める」） |
///
/// ★★ 「同じ」の定義を★ここでは決めない ★★
/// ★**利用者名の正規化は★どの決定にも書かれていない**（★§46-14 の 2）。
/// → ★**この実装は★★受け取った字面をそのまま鍵にする★★**（`auth.dart` の doc と同じ）。
library;

import 'dart:convert';
import 'dart:io';

import 'auth.dart';
import 'json_field.dart';

/// 保管したファイルの形の版。
///
/// ★★ 中身の形が変わったら上げる ★★
/// ★**`loveca_db` の `schemaVersion` とは★★別物である★★**（★§48-5 —— ★共有しないために分けた）。
const int accountFileVersion = 1;

/// [AccountStore] の実装 —— ★JSON のファイル 1 つ。
///
/// ★★ 読み込みは★開いたときに 1 度だけ行う ★★
/// ★**引くたびに読み直さない**（★1 つのプロセスが持つという仮定の上に立つ）。
class AccountFileStore implements AccountStore {
  AccountFileStore._(this._file, this._rows);

  final File _file;
  final Map<String, AccountRecord> _rows;

  /// [path] のファイルを開く。★**無ければ空として開く**（★作らない）。
  ///
  /// ★★ 「無い」は異常ではない ★★
  /// ★**最初の 1 件を書くまでファイルは存在しない。**
  /// ★**壊れていれば投げる**（★空として開くと★★全アカウントが静かに消える★★）。
  factory AccountFileStore.open(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return AccountFileStore._(file, <String, AccountRecord>{});
    }
    return AccountFileStore._(file, _parse(file.readAsStringSync()));
  }

  static Map<String, AccountRecord> _parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('★保管のファイルが JSON として読めない: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★保管のファイルの中身が表ではない');
    }
    final version = decoded['version'];
    if (version != accountFileVersion) {
      // ★★ 知らない版は投げる（★推測で読まない）★★
      //   ★空として扱うと★★全アカウントが静かに消える★★。
      throw FormatException('★知らない版: $version');
    }
    final accounts = decoded['accounts'];
    if (accounts is! List<Object?>) {
      throw const FormatException('★accounts が列ではない');
    }
    final rows = <String, AccountRecord>{};
    for (final row in accounts) {
      if (row is! Map<String, Object?>) {
        throw const FormatException('★accounts の要素が表ではない');
      }
      final record = AccountRecord(
        userName: requireJsonString(row, 'userName'),
        passwordHash: requireJsonString(row, 'passwordHash'),
      );
      if (rows.containsKey(record.userName)) {
        // ★★ 読み込みでも重複を断る（★柵 2 の裏側）★★
        //   ★手で書き足したファイルが★★静かに片方を捨てる★★のを防ぐ。
        throw FormatException('★同じ利用者名が 2 つ在る: ${record.userName}');
      }
      rows[record.userName] = record;
    }
    return rows;
  }

  @override
  AccountRecord? findByUserName(String userName) => _rows[userName];

  /// いま保管しているアカウントの数。★**試験と診断のためだけに在る。**
  int get count => _rows.length;

  /// アカウントを 1 件足す。
  ///
  /// ★★ 重複は断る（★柵 2 / 決定 **D130-9**）★★
  /// ★**サーバーが一意性を保つ**と決まっており、★**ここがその場所である。**
  /// ★**既に在れば [StateError] を投げる**（★上書きしない —— ★★黙って別人のパスワードを置き換える★★）。
  ///
  /// ★★ 口ではない ★★
  /// ★**アカウントを★作る★★口★★は★§32-6 のどのコミットにも無い**（★§48-12 の 1）。
  /// ★**これは★保管の側の書き込みである。**
  void add(AccountRecord account) {
    if (_rows.containsKey(account.userName)) {
      throw StateError('★同じ利用者名が既に在る: ${account.userName}');
    }
    _rows[account.userName] = account;
    _flush();
  }

  /// ★★ 一時ファイルへ書いてから置き換える（★柵 1）★★
  /// ★**直に書くと、★途中で落ちたときに★★全アカウントが消える★★。**
  /// ★**置き換えは同じ入れ物の中で行う**（★別の入れ物へまたぐと 1 手で済まない）。
  void _flush() {
    final rows = _rows.values.toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));
    final body = jsonEncode({
      'version': accountFileVersion,
      'accounts': [
        for (final row in rows)
          {'userName': row.userName, 'passwordHash': row.passwordHash},
      ],
    });

    final temp = File('${_file.path}.tmp');
    temp.parent.createSync(recursive: true);
    temp.writeAsStringSync(body, flush: true);
    // ★`rename` は同じ入れ物の中なら 1 手である。★既に在っても置き換える。
    temp.renameSync(_file.path);
  }
}
