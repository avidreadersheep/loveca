/// 認証の判定（決定 **D130** / `docs/同期設計メモ.md` §46-11 / §46-12）。
///
/// ★★ これは §32-6 の 16（認証の口）ではない ★★
/// ★**口は 1 つも開いていない。**★待ち受けも保管も 1 行も無い。
/// ★ここに在るのは「★★受け取った要求から★誰かを判定して★応答を返す★★」部分だけである。
///
/// ★★ 16 が待っている 2 つを 1 つも要らない（★1 つずつ当てた / §46-11）★★
///
/// | 待っているもの | ★この判定はこれを要るか |
/// |---|---|
/// | ★**門 シ**（**N-24** ＝ 待ち受けられるか） | ★★**要らない**★★ —— ★判定は**受け取ったあと**に走る |
/// | ★**アカウントの保管**（★§35-9 が未決 / **D126-4** の 3 段目） | ★★**要らない**★★ —— ★**保管を[AccountStore]として★渡される口にした**（★先例は `loveca_db` の `MasterFileSource`） |
///
/// ★**§32-6 の 13（★衝突判定を純粋関数として置く）と★★同じ形である★★。**
/// ★**§45 で置いた [encodePasswordHash] / [verifyPassword] の★★最初の消費者である★★**
/// （★あれは消費者 0 のまま置かれた）。
///
/// ---
///
/// ## ★★ この判定が前提にしている決定 ★★
///
/// | 決定 | 何を定めたか | ★ここでの形 |
/// |---|---|---|
/// | **D129-1** | ★名乗るのは**利用者名とパスワード** | ★[AuthRequest] の 2 つのフィールド |
/// | **D130-1** | ★識別子は**利用者名**（★アドレスではない） | ★★**形の上では区別が付かない。★doc に書く**★★（★下の「★書けないこと」） |
/// | **D130-10** | ★**パスワードそのものを送る**（★端末で導き直さない） | ★[AuthRequest.password] は**そのまま**である |
/// | **D130-12** | ★本文は **JSON** | ★[AuthRequest.fromJson] / [AuthResponse.toJson] |
/// | **D130-13** | ★★**要求に★端末の同定を入れない**★★ | ★**フィールドが 2 つしか無いこと自体が★その決定である**（★対で固定した） |
/// | **D129-3** | ★保存は PBKDF2-HMAC-SHA256 | ★[verifyPassword] を呼ぶ（★このファイルは算法を 1 つも知らない） |
/// | **D123-1** | ★利用者と端末は**別の量** | ★[AuthSuccess] が返すのは**利用者の同定 1 つだけ**である |
///
/// ---
///
/// ## ★★ 柵 —— ★★失敗の理由を分けない ★★
///
/// ★**「利用者名が無い」と「パスワードが違う」を★★区別して返さない★★。**
/// ★区別すると、★**利用者名が在るかどうかが★外から分かる。**
///
/// ★★**ただしこれは★片側しか塞げない**★★ —— ★**アカウントを作る口は★重複を断る**
/// （**D130-9**）ので、★★そちら側では必ず漏れる★★。
/// ★**その口は §32-6 のどのコミットにも無い**（`docs/同期設計メモ.md` §46-14 の 1）。
/// → ★★**塞ぎ方は★その口を作るときに★一緒に決めること。★ここだけ塞いでも埋まらない。**★★
///
/// ---
///
/// ## ★★ 書けないこと（★**D-28** —— ★推測で埋めない）★★
///
/// - ★**利用者名の★正規化**（★大文字小文字 / 全角半角 / 前後の空白）は★**どの決定にも書かれていない**
///   （★同 §46-14 の 2）。→ ★**このファイルは★★受け取った字面をそのまま鍵にする★★。**
///   ★**「同じ」の定義は [AccountStore] の実装が持つ。**
/// - ★**利用者名の長さや使える文字も★決まっていない。**★**検査を入れない**
///   （★入れると★★決まっていない規則を決めたことになる★★）。
library;

import 'json_field.dart';
import 'password_hash.dart';

/// 認証の要求（決定 **D129-1** / **D130-10** / **D130-12** / **D130-13**）。
///
/// ★★ フィールドは 2 つだけである ★★
/// ★**端末の同定は入らない**（**D130-13**）。★**入れると 26（端末の名簿）の形を先に決めてしまう。**
class AuthRequest {
  const AuthRequest({required this.userName, required this.password});

  /// 名乗るときの識別子（決定 **D130-1** ＝ **利用者名**）。
  ///
  /// ★**正規化しない**（★上の「書けないこと」）。★受け取った字面をそのまま持つ。
  final String userName;

  /// ★**そのままのパスワード**（**D130-10**）。
  ///
  /// ★★ 経路が秘匿であることが前提である（**D129-6** / **D130-5**）★★
  /// ★**素の HTTP に載せてはならない。**★載せると保存をどれだけ固くしても意味が無い。
  final String password;

  /// JSON から読む。★**壊れていれば [FormatException] を投げる。**
  ///
  /// ★★ 「無い」と「空」を分ける ★★
  /// ★**鍵が無い**のは**壊れた要求**であり、★**空文字**は**間違った資格情報**である。
  /// → ★前者は投げ、★後者は [authenticate] が `false` を返す。
  factory AuthRequest.fromJson(Map<String, Object?> json) {
    return AuthRequest(
      userName: requireJsonString(json, 'userName'),
      password: requireJsonString(json, 'password'),
    );
  }

  Map<String, Object?> toJson() => {
        'userName': userName,
        'password': password,
      };
}

/// 認証の応答。
///
/// ★★ 成功と失敗を★型で分ける ★★
/// ★**`bool` にすると、★★成功のときだけ在る値（利用者の同定）を★どこに置くかで迷う。**
sealed class AuthResponse {
  const AuthResponse();

  /// JSON にする。★**失敗の側に★理由を 1 つも入れない**（★上の柵）。
  Map<String, Object?> toJson();
}

/// 名乗れた。★返すのは**利用者の同定 1 つだけ**である（**D123-1**）。
final class AuthSuccess extends AuthResponse {
  const AuthSuccess(this.userName);

  /// ★**保管に在った字面**である（★要求の字面ではない）。
  ///
  /// ★★ なぜ保管の側を返すか ★★
  /// ★[AccountStore] が★正規化して引いた場合、★★要求の字面と保管の字面は違いうる★★。
  /// ★**以降の層が使うのは★保管の側である**（★デッキの持ち主を引く鍵になる）。
  final String userName;

  @override
  Map<String, Object?> toJson() => {'ok': true, 'userName': userName};
}

/// 名乗れなかった。
///
/// ★★ 理由を持たない。★フィールドが 1 つも無いこと自体が柵である ★★
/// ★**「利用者名が無い」と「パスワードが違う」を区別できない形にしてある。**
/// ★**足せてしまうが、★足したら上の柵が破れる**（★対で固定した）。
final class AuthFailure extends AuthResponse {
  const AuthFailure();

  @override
  Map<String, Object?> toJson() => {'ok': false};
}

/// アカウント 1 件の記録。
///
/// ★★ 保管の形は決めていない（★§35-9 / **D126-4** の 3 段目）★★
/// ★**これは「保管から出てくる値」であって、★★保管そのものではない★★。**
class AccountRecord {
  const AccountRecord({required this.userName, required this.passwordHash});

  /// ★**保管に在る字面**（★[AuthSuccess] が返すのはこちらである）。
  final String userName;

  /// ★[encodePasswordHash] が作った値（決定 **D129-3**）。
  ///
  /// ★**このファイルは中身を 1 バイトも読まない。**★[verifyPassword] に渡すだけである。
  final String passwordHash;
}

/// アカウントの保管の**口**。
///
/// ★★ 実装をここに置かない（★§35-9 が未決 / **D126-4** の 3 段目）★★
/// ★**サーバーが何で保管するかは★決まっていない。**
/// ★**「決めていない」を「決めた」に変えないために、★★口だけ置く★★**
/// （★先例は `loveca_db` の `MasterFileSource` —— ★「取得手段は呼び出し側が渡す」）。
///
/// ★★ 「同じ」の定義はこの実装が持つ ★★
/// ★利用者名の正規化は**どの決定にも書かれていない**（★上の「書けないこと」）。
abstract interface class AccountStore {
  /// [userName] のアカウントを返す。★無ければ `null`。
  ///
  /// ★**投げないこと。**★**無いことは★★異常ではない★★**（★間違った利用者名は日常である）。
  AccountRecord? findByUserName(String userName);
}

/// 認証の判定（★★純粋関数★★ / **D130-14**）。
///
/// ★★ この関数は★口を 1 つも開かない ★★
/// ★**待ち受けない。★保管しない。★時刻も乱数も引かない。**
/// ★★**同じ入力から同じ結果が出る**★★（★`loveca_core` の `reduce` と同じ性質。
/// ★ただし **D127-5** のとおり★このパッケージは `loveca_core` を 1 つも呼ばない）。
///
/// ★★ 失敗の理由を分けない（★柵）★★
/// ★**アカウントが無い場合も、★パスワードが違う場合も★★同じ [AuthFailure] を返す。**
AuthResponse authenticate(AuthRequest request, AccountStore store) {
  final account = store.findByUserName(request.userName);
  if (account == null) {
    return const AuthFailure();
  }
  if (!verifyPassword(request.password, account.passwordHash)) {
    return const AuthFailure();
  }
  return AuthSuccess(account.userName);
}
