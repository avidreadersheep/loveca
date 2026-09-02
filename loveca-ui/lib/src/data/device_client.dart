/// ★★ 端末の名簿の口（アプリ側）—— §32-6 の **26** の 3 番目（決定 **D145**）★★
///
/// ★★ 口と★1 つの配線だけである。★画面は 1 行も無い ★★
/// ★**いつ呼ぶか / ★どう見せるかは★★§32-6 の 25 である★★**（★未着手 / ★運転指示【2】——
/// ★★UI は差し込み口まで作って止める★★）。
///
/// ---
///
/// ## ★★ 何のために呼ぶのか —— ★★引き金である（**D145-2** ＝ 引-1）★★
///
/// ★**サーバーが「★★名簿に居たか★★」の 1 ビットを返す。**
/// ★**居なかったら、★★器の行を消して「まだ一度も同期していない」に戻す★★**
/// （**D119-5** ＝ 失-1 ／ **D121-7** ＝ 落-1 —— ★★遷移先が同じである★★）。
///
/// ★★ 「新しい端末」と「外れて戻ってきた端末」を★区別しない ★★
/// ★**§27-4 が「★外された端末にとって『捨てられた』は『失った』と区別がつかない」と書き、
/// ★**D121-7** が★★その理由で 落-1 を採った★★。**
/// ★**新しい端末では★器の行が★元から 0 件なので、★★何も消えない★★**（★同じ答えで正しい）。
///
/// ## ★★ 端末の同定は★端末が自分で作る（**D123-3** ＝ 端-1 / **D145-3** ＝ 置-1）★★
///
/// ★**`loveca_core` では作れない**（`CLAUDE.md` §1 が seed なしの乱数を禁じている）。
/// ★**作るのは★ここである**（★`deck_id.dart` の `randomDeckIdV4` を★そのまま使う）。
/// ★★**秘密ではない**★★ —— ★**名乗りは★利用者名とパスワードである**（**D129-1**）。
/// ★**この値は★★名簿の見出しであって★資格情報ではない★★**（★★混ぜない★★ / **§7-7**）。
///
/// ## ★★ 答えの分け方は★18 / 21 / 23 と同じである（**D105-6** / **D132-6**）★★
///
/// ★**`SyncOutcome` を★そのまま使う** —— ★★口ごとに別の型を作らない★★。
///
/// ## ★★ 名乗りは★要求ごとに運ぶ ★★
///
/// ★**送るものは★パスワードそのものである**（**D130-10**）。
/// ★★**持ち越す仕組みは★1 つも決まっていない**★★（**N-21** の (4)）。
library;

import 'dart:io';

import 'package:loveca_db/loveca_db.dart';

import 'deck_id.dart';
import 'deck_sync_client.dart';

/// 名簿の口のパス（★★サーバー側と★同じ字面★★ / **D126-3** の代償）。
const String devicesPath = '/devices';

/// 要求の鍵（★端末の同定）。
const String syncDeviceIdKey = 'deviceId';

/// ★★ 要求の鍵（★名簿へ★入れてよいか）—— **D148-1** ★★
///
/// ★★ 省けない（★サーバー側が★鍵の不在を 400 で断る）★★
/// ★**既定を `false` に読むと、★★鍵を落とすだけで★端末が永久に名簿へ入れず、
///   ★同期のたびに器が消える★★**（★先例は **D141-4**）。
const String syncJoinKey = 'join';

/// 応答の鍵（★名簿に居たか）。
const String syncKnownKey = 'known';

/// 同（★名簿の全件）。
const String syncDeviceIdsKey = 'deviceIds';

/// 名簿を引いた結果。
///
/// ★★ 1 ビットと★全端末の集合 ★★
/// ★**[known] が `false` なら★呼ぶ側は★★器を戻す★★**（★下の [syncDeviceRoster]）。
/// ★**[deviceIds] は★★自分を含む★★**（★自分も全端末の 1 つである / **N-19** の 事実 1）。
typedef DeviceRoster = ({bool known, List<String> deviceIds});

/// 名簿に触れる（★§32-6 の **26** の 3 番目）。
///
/// ★★ 投げない（★18 / 21 / 23 と同じ） ★★
///
/// ★★ [join] —— ★★名簿へ★入れてよいか（**D148-1**）★★
/// ★**`false` なら★★名簿に居ない端末を★書き加えない★★**（★居る端末の時刻は書き直す）。
/// ★**省けない**（★サーバーが★鍵の不在を 400 で断る / ★上の [syncJoinKey]）。
Future<SyncOutcome<DeviceRoster>> touchDeviceRoster({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required String deviceId,
  required bool join,
}) async {
  return postSyncRequest<DeviceRoster>(
    client: client,
    server: server,
    path: devicesPath,
    body: <String, Object?>{
      syncUserNameKey: userName,
      syncPasswordKey: password,
      syncDeviceIdKey: deviceId,
      syncJoinKey: join,
    },
    read: (decoded) {
      final known = decoded[syncKnownKey];
      final ids = decoded[syncDeviceIdsKey];
      // ★★ 1 ビットが欠けていたら★受け取らない ★★
      //   ★**受け取ると、★★引き金が立たないまま先へ進む★★**
      //     （★外れた端末が★古い器のまま同期を続ける）。
      if (known is! bool || ids is! List<Object?>) return null;
      final out = <String>[];
      for (final id in ids) {
        if (id is! String) return null;
        out.add(id);
      }
      return (known: known, deviceIds: out);
    },
  );
}

/// 器を全部忘れる口（★★置き場は呼び出し側が渡す★★ / **D131-5** の柵 3 と同じ形）。
///
/// ★**`DeckSyncMarkDao` を直に受けない** —— ★★受けると★DB 無しで試験できない★★
/// （★先例は `DeckSyncMarks` / `MasterFileSource`）。
abstract interface class DeviceIdentityStore {
  /// いまの同定（★行が無ければ / ★中途なら `null`）。
  Future<SyncIdentity?> currentIdentity();

  /// 名乗る（★★利用者名と端末の同定を★同じ行に書く★★ / **D145-3**）。
  Future<void> recordIdentity({
    required String userName,
    required String deviceId,
  });

  /// ★★ 器の行を★全部消す（★§32-6 の **27** ＝ **D119-5** / **D121-7**）★★
  ///
  /// ★**「まだ一度も同期していない」に戻す**（★機構は **D114-3**）。
  /// ★★**編集ログには触れない**★★ —— ★**未送信の編集は★★失わせない★★**
  ///   （★捨てる規則は **N-16** / **Q-10** であり、★★この口の論点ではない★★）。
  Future<void> forgetAllMarks();
}

/// 名簿に触れて、★★外れていたら器を戻す★★（★§32-6 の **26** ＋ **27** の配線）。
///
/// ## ★★ 端末の同定が無ければ★ここで作る ★★
///
/// ★**`current()` が `null`（★行の不在 / ★中途）なら★★新しく作って記録する★★。**
/// ★**そのときは★サーバーから見ても「初めて」なので、★★`known` は必ず `false` になる★★** ——
///   ★**器を戻すが、★★行が 0 件なら何も消えない★★**（★上の doc）。
///
/// ## ★★ 順序 —— ★★問う → ★器を消す → ★記録する（**D148-1** / ★運転指示【0】(4)）★★
///
/// ★**§80-4 が「★途中で落ちたときは★★自分で直らない★★」と記録した分である。**
/// ★★**新しい量を置く前に、★順序で解けるかを見た。★解けた**★★（★相談役の指示）。
///
/// | 段 | 何をするか | ★ここで落ちたら |
/// |---|---|---|
/// | ★**1** | ★**名簿に★問う**（`join: false` —— ★★1 行も増やさない★★） | ★**名簿は古いまま** → ★次の同期が★同じ経路 |
/// | ★**2** | ★**器の行を★全部消す** | ★**同上**（★名簿にまだ入っていない） |
/// | ★**3** | ★**名簿へ★入る**（`join: true`） | ★**同上** |
///
/// ★★**単純な入れ替え（★器を先に消して★名簿を後に）は★成立しない**★★ ——
/// ★**「消すかどうか」は★★サーバーの答えで決まる★★。★答えの前には消せない。**
/// ★**無条件に消すと、★★つながるたびに基準を捨てる★★**（★次の同期が全件を衝突として解く）。
/// → ★**成立するのは「★★判定と記録を分けて、★記録を後ろへ移す★★」形だけである。**
///
/// ★★ 冪等である ★★
/// ★**[DeviceIdentityStore.forgetAllMarks] は★★2 度消しても結果が同じ★★**（★対で固定した）。
/// → ★**同じ経路を何度通っても★★1 度通ったのと同じ状態になる★★。**
///
/// ★★ 代償を隠さない —— ★★名簿に居ないときは★1 回多く投げる ★★
/// ★**定常（★名簿に居る）は★★1 回のまま★★。★名簿に居ないときだけ★★2 回★★。**
/// → ★**1 回の同期 ＝ ★2 ＋ デッキの数（定常）／ ★★3 ＋ デッキの数（名簿に居ないとき）★★。**
/// ★**上限の側は★★悪いほうで見る★★**（`loveca-server/test/sync_burst_test.dart`）。
/// ★★**「小さい」とは書かない**★★（**D-28**）—— ★**書けるのは★★1 回増えることまで★★である。**
///
/// ## ★★ 通信が失敗したら★器を 1 バイトも触らない ★★
///
/// ★**触ると、★★つながらなかっただけで★基準を捨てる★★**（★次の同期が全件を衝突として解く）。
/// → ★**対で固定した。**
///
/// ## ★★ 名乗れなかったときも★触らない ★★
///
/// ★**パスワードを間違えただけで★★基準が消える★★のは★同じ形の害である。**
Future<SyncOutcome<DeviceRoster>> syncDeviceRoster({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required DeviceIdentityStore identity,
  String Function() newDeviceId = randomDeckIdV4,
}) async {
  final current = await identity.currentIdentity();
  final deviceId =
      current != null && current.userName == userName
          ? current.deviceId
          : newDeviceId();
  if (current == null ||
      current.userName != userName ||
      current.deviceId != deviceId) {
    await identity.recordIdentity(userName: userName, deviceId: deviceId);
  }

  // ★★ 段 1 —— ★問う（★★名簿を 1 行も増やさない★★ / **D148-1**）★★
  final asked = await touchDeviceRoster(
    client: client,
    server: server,
    userName: userName,
    password: password,
    deviceId: deviceId,
    join: false,
  );
  if (asked case SyncOk<DeviceRoster>(:final value) when !value.known) {
    // ★★ 段 2 —— §32-6 の 27 ＝ ★器の行を消して「まだ一度も同期していない」に戻す ★★
    await identity.forgetAllMarks();

    // ★★ 段 3 —— ★名簿へ入る（★★器を消したあとである★★）★★
    //   ★**ここで落ちても★★名簿は古いまま★★なので、★次の同期が★同じ経路を通る。**
    return touchDeviceRoster(
      client: client,
      server: server,
      userName: userName,
      password: password,
      deviceId: deviceId,
      join: true,
    );
  }
  return asked;
}

/// ★★ `loveca_db` の DAO を [DeviceIdentityStore] に嵌める（★★橋渡しだけ★★）★★
///
/// ★★ 判断を 1 つも持たない ★★
/// ★**3 つのメソッドを★そのまま通す**（★先例は `DeckSyncMarkDaoMarks` —— ★同じ形）。
/// ★**この層で条件を足さない**（★足すと★試験の外に出る）。
///
/// ★★ 2 つの DAO をまたぐ ★★
/// ★**同定は `sync_identities`、★器は `deck_sync_marks`** —— ★★別の表である★★
/// （**D125-9** —— ★器はデッキごと、★同定は DB 全体で 1 つ）。
/// ★★**トランザクションにしていない。★隠さない**★★ ——
/// ★**この層は★★新しいトランザクションを 1 つも開かない★★**（**D55** の線 / ★**D144** と同じ断り）。
///
/// ★★ 途中で落ちたときは★自分で直らない。★記録する（★手当てしていない / **D-28**）★★
/// ★**名簿に触れたあとで [forgetAllMarks] が落ちると、★★次の同期は `known: true` を返す★★**
///   （★★名簿には★既に記録されている★★）。→ ★**器が★★古いまま残る★★。**
/// ★★**「次の同期が同じことをする」とは書かない。★成り立たない**★★（★実読）。
/// ★**手当てには★★新しい量が要る**★★（★「名簿に受け入れられたことを★端末側でも覚える」）——
///   ★**今日は置かない**（**D114-7** の理由 2）。
///
/// ★★ 2026-09-02 追記: ★★手当てした。★新しい量は 1 つも要らなかった（**D148-1**）★★
/// ★★**上の 5 行は 1 文字も書き換えない**★★（**D-35** —— ★★その順序では真である★★）。
/// ★**順序を「★問う → ★器を消す → ★記録する」に変えた**（★[syncDeviceRoster] の doc）。
/// → ★**途中で落ちても★★名簿は古いまま★★なので、★次の同期が★同じ経路を通る。**
/// ★**[forgetAllMarks] は★★冪等である★★**（★2 度消しても★結果が同じ）。
class DaoDeviceIdentityStore implements DeviceIdentityStore {
  const DaoDeviceIdentityStore(this._identity, this._marks);

  final SyncIdentityDao _identity;
  final DeckSyncMarkDao _marks;

  @override
  Future<SyncIdentity?> currentIdentity() => _identity.current();

  @override
  Future<void> recordIdentity({
    required String userName,
    required String deviceId,
  }) =>
      _identity.record(userName: userName, deviceId: deviceId);

  @override
  Future<void> forgetAllMarks() => _marks.forgetAll();
}
