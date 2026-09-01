/// ★★ 送信の配線 —— ★判定 → 解決 → 送る ＋ 器への記録点（★§32-6 の **23** / 決定 **D143**）★★
///
/// ★★ この口が★書き込むのは★器だけである ★★
/// ★**手元の `Deck` を★1 バイトも書き換えない**（★受信は★★§32-6 の **24** である★★ / ★未着手）。
/// → ★**相手側が勝った場合は★[DeckSyncRemoteWins] を返して★★止まる★★。**
///
/// ---
///
/// # ★★ 門 カ（初回同期）を洗って決めた —— ★★初-1 ＝ 決着層で解く ★★
///
/// ★**器の行が無いとき**（`DeckConflictVerdict.neverSynced` / **D114-3**）**に何をするか。**
///
/// | 案 | ★**(甲) 何が失われうるか** | ★**(乙) 収束するか** | ★**(丙) 新しい規則が要るか** | ★**(丁) 決まっている決定と当たるか** |
/// |---|---|---|---|---|
/// | ★★**初-1 決着層で解く（★採った）**★★ | ★**新しくないほう** | ★**する**（★決着層は全順序 / **D138-1**） | ★★**0**★★ | ★**当たらない** |
/// | ★**初-2 常に相手を採る** | ★★**手元が★必ず消える**★★（★★中身と時刻に関わらず★★） | ★する | 0 | ★★**D107-2 と当たる**★★（★2 台で編集するのは★日常である） |
/// | ★**初-3 常に自分を採る** | ★★**相手が★必ず消える**★★（★同上） | ★する | 0 | ★同上 |
/// | ★**初-4 利用者に選ばせる** | —— | —— | —— | ★★**D113-1 が★既に閉じている**★★（★選ばせる口は置かない） |
///
/// ★★**初-4 は★候補ではない。★★決定が閉じている★★**★★（**D113-1**）—— ★**開き直す条件は **D113-3** に在る。**
/// ★★**初-2 / 初-3 は「劣る」のではない。★★(甲) が harm である★★**★★ ——
/// ★**1 か月編集した端末の中身が、★★別の端末が初めて同期した瞬間に消える★★。**
/// ★★**初-1 は★新しい規則を 1 つも要らない**★★ —— ★**衝突と★同じ層を通す**（★**D125-2** が 帰-2 を採ったのと同じ物差し）。
///
/// ★★ なぜ「衝突と同じ」でよいか ★★
/// ★**基準が無い ＝ ★★どちらが変わったかを測れない★★**（★§18-2-4 の G の前提が立たない）。
/// → ★**「両側が変わったかもしれない」が★★最も弱い仮定★★である。★それは `conflict` と同じ場面である。**
///
/// ★★ 2026-09-02 追記: ★★段 3 の根拠は **D107** である★★（★運転指示【0】(2)）★★
///
/// ★★**上の 3 行は 1 文字も書き換えない**★★（**D-35** —— ★★1 つも偽ではない★★）。
/// ★★**足りないのは★1 段だけである** —— ★「★最も弱い仮定を採る」ことそのもの。★★
///
/// | 段 | 何 | ★これは何か |
/// |---|---|---|
/// | ★**1** | ★器の行が無い（`neverSynced` / **D114-3**） | ★★**事実**★★ |
/// | ★**2** | → ★どちらが変わったかを★★測れない★★ | ★★**事実**★★ |
/// | ★★**3**★★ | → ★★**最も弱い仮定を採る**★★ | ★★**方針である。★論理ではない**★★ |
/// | ★**4** | → ★`conflict` と同じ場面 | ★**帰結**（★段 3 を認めれば導ける） |
///
/// ★★ 段 3 は **D107-1** の後半から導かれる ★★
/// ★**「★★消える前に知らせる、または消えたことが後から分かるようにする★★」。**
/// ★**より強い仮定（「片方だけが変わった」）を採ると、★★実際には両側が変わっていた場合に
///   ★片方が★黙って消える★★** → ★★**D107-1 の後半が★正面から破れる**★★。
/// → ★★**段 3 は★好みではない。★決定から導かれる。**★★
///
/// ★★ 従属 —— ★★D107 が動けば★この段も動く★★ ★★
/// ★**D107 は★★利用者判断である★★**（**D107-1** ＝ 仕様の希望）ので★覆りうる
///   （★先例は **D129** が **D128** を覆した）。
/// ★**「黙って消えてもよい」に変われば、★★初-2 / 初-3 が★候補として戻る★★**
///   （★★どちらも収束し、★新しい規則も要らない★★ —— ★上の表の (乙)(丙)）。
/// ★**「知らせる」の側だけが弱まっても★段 3 は★★残る★★**（★「後から分かる」が生きている限り）。
///
/// ---
///
/// # ★★ 落ちたログの扱い（**D111-2** が「23 が決める」と書いた分）★★
///
/// ★`droppedLocalOpsByContent` は「★★操作は在るが★内容が基準と一致する★★」である。
///
/// | 場合 | ★どうするか |
/// |---|---|
/// | ★**差し引きゼロの編集**（★足して消した） | ★★**目印を進める**★★（★★次回また見ない★★ / ★内容は 1 ビットも動いていない） |
/// | ★★**論理削除だけが起きた**★★ | ★★**送る**★★（★下） |
///
/// ★★**論理削除は★内容ハッシュに 1 ビットも現れない**★★（**D111-4** —— ★`deletedAt` は 5 フィールドに無い / **D116-12**）。
/// → ★**目印を進めるだけだと、★★削除が★永久に送られない★★。**
/// → ★**`deletedAt` が★相手と違うかを見る**（★★両方の `Deck` が手元に在るので★新しい量を 1 つも要らない★★）。
///
/// ★★**判定の側に足していない**★★ —— ★**`judgeDeckConflict` に削除の例外を足すのは
/// ★★(f-1) を開き直すことである★★**（★あの doc が自らそう書いている）。★**送信の側で見た。**
///
/// ★★**`unchanged` のときは★`dropped` かどうかに関わらず見る**★★ ——
/// ★**費用が 0 で、★★見落としの側だけが害である★★**（★★推測で狭めない★★）。
///
/// ---
///
/// # ★★ 再試行は 0 回である（**D141-3** ＝ 再-1）★★
///
/// ★**412 が返ったら [DeckSyncStale] を返して★★止まる★★。**
/// ★**取り直して解き直すのは★呼ぶ側である**（★いつ・どう見せるかは★★§32-6 の 25★★ / ★未着手）。
///
/// # ★★ 目印は★★先に★★取る ★★
///
/// ★**`latestLogMark` を★★何よりも先に読む★★。**
/// → ★**同期のあいだに編集が入っても、★★その操作の id は★取った目印より大きい★★**
///   ので、★★次の同期で「まだ送っていない」として現れる★★（★安全側）。
/// ★**逆にすると★★送っていない編集を★送ったことにする★★。**
library;

import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import 'deck_sync_client.dart';

/// ★器（`deck_sync_marks`）の口（★★置き場は呼び出し側が渡す★★ / **D131-5** の柵 3 と同じ形）。
///
/// ★★ `loveca_db` の DAO を★直に受けない ★★
/// ★**受けると★★DB 無しで試験できない★★**（★先例は `MasterFileSource`）。
abstract interface class DeckSyncMarks {
  /// [deckId] の基準（★行が無ければ `null` / **D114-3**）。
  Future<DeckSyncBaseline?> baselineFor(String deckId);

  /// [deckId] の編集ログの★いちばん新しい id（★1 件も無ければ 0 / **D140-1**）。
  Future<int> latestLogMark(String deckId);

  /// 器に書く。
  Future<void> record({
    required String deckId,
    required int logMark,
    required String baselineHash,
  });
}

/// 1 つのデッキを同期した結果。
sealed class DeckSyncOutcome {
  const DeckSyncOutcome();
}

/// ★何も送らなかった（★どちら側も基準から動いていない）。
final class DeckSyncSkipped extends DeckSyncOutcome {
  const DeckSyncSkipped({required this.advancedMark});

  /// ★★ 目印だけ進めたか（★差し引きゼロの編集が在った）★★
  final bool advancedMark;
}

/// ★送った（★器にも記録した）。
final class DeckSyncSent extends DeckSyncOutcome {
  const DeckSyncSent({required this.created, required this.mark});

  /// ★新しく預かったか（★201）／ ★上書きしたか（★200）。
  final bool created;

  /// ★預けたあとの印（★次に預けるときに名乗る）。
  final String mark;
}

/// ★★ 相手側が勝った。★★手元へ書くのは §32-6 の 24 である★★ ★★
///
/// ★**この口は★★手元を 1 バイトも書き換えない★★。**
final class DeckSyncRemoteWins extends DeckSyncOutcome {
  const DeckSyncRemoteWins({
    required this.remote,
    required this.mark,
    required this.reason,
  });

  /// ★受け取った版（★★組んである★★ / **D142-3**）。
  final Deck remote;

  /// ★そのときの印（★24 が器に記録するときに要る）。
  final String mark;

  /// ★なぜ相手側なのか（★判定で決まったのか / ★解決で決まったのか）。
  final DeckSyncRemoteReason reason;
}

/// [DeckSyncRemoteWins] の理由。
enum DeckSyncRemoteReason {
  /// ★相手側だけが変わっていた（★判定 / `remoteOnly`）。
  remoteOnly,

  /// ★両側が変わり、★解決で相手側が勝った。
  resolved,
}

/// ★★ 取ったときの印が合わなかった（★412 / **D139-1**）★★
///
/// ★**再試行は 0 回である**（**D141-3**）—— ★**取り直して解き直すのは★呼ぶ側。**
final class DeckSyncStale extends DeckSyncOutcome {
  const DeckSyncStale();
}

/// ★名乗れなかった（★401）。
final class DeckSyncNotAuthorized extends DeckSyncOutcome {
  const DeckSyncNotAuthorized();
}

/// ★つながらない / ★応答が期待どおりでない / ★受け取った字面が読めない。
final class DeckSyncFailed extends DeckSyncOutcome {
  const DeckSyncFailed(this.reason);

  /// ★**利用者に出すためではなく、★診断のために持つ**（★見せ方は §32-6 の **25**）。
  final String reason;
}

/// ★★ デッキ 1 つを同期する（★送る側だけ）★★
///
/// ★★ 手元を 1 バイトも書き換えない ★★
/// ★**書き込むのは★器だけである**（★★送れたときだけ★★）。
///
/// ★★ 投げない ★★
/// ★**読めなかった字面も★[DeckSyncFailed] にして返す**（**D105-6** と同じ形）。
Future<DeckSyncOutcome> syncOneDeck({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required Deck local,
  required DeckSyncMarks marks,
}) async {
  // ★★ 目印を★何よりも先に取る（★上の doc）★★
  final logMark = await marks.latestLogMark(local.deckId);
  final baseline = await marks.baselineFor(local.deckId);

  final fetched = await fetchRemoteDeck(
    client: client,
    server: server,
    userName: userName,
    password: password,
    deckId: local.deckId,
  );

  switch (fetched) {
    case SyncRejected<RemoteDeck>():
      return const DeckSyncNotAuthorized();
    case SyncUnreachable<RemoteDeck>(:final reason):
      return DeckSyncFailed(reason);
    case SyncStale<RemoteDeck>():
      // ★★ 取る口は★412 を返さない（★印を名乗らないので★前提が 1 つも無い）★★
      return const DeckSyncFailed('★取る口が 412 を返した');
    case SyncAbsent<RemoteDeck>():
      // ★★ 相手が持っていない —— ★踏み潰す相手が 1 つも無い ★★
      //   ★**「まだ預けていないはず」と名乗る**（**D141-4**）。
      //   ★★**印が合わなければ★サーバーが断る★★**（★そのあいだに誰かが預けた場合）。
      return _push(
        client: client,
        server: server,
        userName: userName,
        password: password,
        deck: local,
        expectMark: null,
        logMark: logMark,
        marks: marks,
      );
    case SyncOk<RemoteDeck>(:final value):
      final Deck remote;
      try {
        remote = decodeDeckForSync(value.content);
      } on FormatException catch (e) {
        // ★★ 埋めない（**D142-3**）—— ★★読めない字面は★読めないと言う★★ ★★
        return DeckSyncFailed('$e');
      }
      return _decide(
        client: client,
        server: server,
        userName: userName,
        password: password,
        local: local,
        remote: remote,
        remoteMark: value.mark,
        baseline: baseline,
        logMark: logMark,
        marks: marks,
      );
  }
}

Future<DeckSyncOutcome> _decide({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required Deck local,
  required Deck remote,
  required String remoteMark,
  required DeckSyncBaseline? baseline,
  required int logMark,
  required DeckSyncMarks marks,
}) async {
  final judged = judgeDeckConflict(
    baseline: baseline,
    localContentHash: deckContentHash(local),
    remoteContentHash: deckContentHash(remote),
  );

  Future<DeckSyncOutcome> resolve(DeckSyncRemoteReason reason) async {
    final resolution = resolveDeckConflict(local: local, remote: remote);
    if (resolution.side == DeckResolutionWinner.remote) {
      return DeckSyncRemoteWins(
        remote: remote,
        mark: remoteMark,
        reason: reason,
      );
    }
    return _push(
      client: client,
      server: server,
      userName: userName,
      password: password,
      deck: resolution.winner,
      expectMark: remoteMark,
      logMark: logMark,
      marks: marks,
    );
  }

  switch (judged.verdict) {
    // ★★ 門 カ —— ★基準が無い。★★衝突と同じ層を通す★★（★初-1 / 上の doc）★★
    case DeckConflictVerdict.neverSynced:
      return resolve(DeckSyncRemoteReason.resolved);

    case DeckConflictVerdict.unchanged:
      // ★★ 論理削除は★内容ハッシュに 1 ビットも現れない（**D111-4** / **D116-12**）★★
      //   ★**`dropped` かどうかに関わらず見る**（★費用が 0 で、★見落としの側だけが害である）。
      if (local.deletedAt != remote.deletedAt) {
        return resolve(DeckSyncRemoteReason.resolved);
      }
      if (judged.droppedLocalOpsByContent) {
        // ★★ 差し引きゼロの編集 —— ★目印だけ進める（★次回また見ない）★★
        await marks.record(
          deckId: local.deckId,
          logMark: logMark,
          baselineHash: deckContentHash(local),
        );
        return const DeckSyncSkipped(advancedMark: true);
      }
      return const DeckSyncSkipped(advancedMark: false);

    case DeckConflictVerdict.localOnly:
      return _push(
        client: client,
        server: server,
        userName: userName,
        password: password,
        deck: local,
        expectMark: remoteMark,
        logMark: logMark,
        marks: marks,
      );

    case DeckConflictVerdict.remoteOnly:
      return DeckSyncRemoteWins(
        remote: remote,
        mark: remoteMark,
        reason: DeckSyncRemoteReason.remoteOnly,
      );

    case DeckConflictVerdict.conflict:
      return resolve(DeckSyncRemoteReason.resolved);
  }
}

/// ★送って、★通ったら器に記録する。
///
/// ★★ 送れなかったら★器を 1 バイトも触らない ★★
/// ★**触ると「送った」と嘘の記録が残る**（★次の同期が★★送っていない編集を見落とす★★）。
Future<DeckSyncOutcome> _push({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required Deck deck,
  required String? expectMark,
  required int logMark,
  required DeckSyncMarks marks,
}) async {
  final pushed = await pushRemoteDeck(
    client: client,
    server: server,
    userName: userName,
    password: password,
    deckId: deck.deckId,
    content: encodeDeckForSync(deck),
    expectMark: expectMark,
  );

  switch (pushed) {
    case SyncOk<RemoteDeck>(:final value):
      await marks.record(
        deckId: deck.deckId,
        logMark: logMark,
        baselineHash: deckContentHash(deck),
      );
      return DeckSyncSent(created: expectMark == null, mark: value.mark);
    case SyncStale<RemoteDeck>():
      return const DeckSyncStale();
    case SyncRejected<RemoteDeck>():
      return const DeckSyncNotAuthorized();
    case SyncUnreachable<RemoteDeck>(:final reason):
      return DeckSyncFailed(reason);
    case SyncAbsent<RemoteDeck>():
      // ★★ 預ける口は★404 を返さない（★対で固定してある）★★
      return const DeckSyncFailed('★預ける口が 404 を返した');
  }
}

/// ★受け取ったデッキを書く口（★★置き場は呼び出し側が渡す★★ / [DeckSyncMarks] と同じ形）。
abstract interface class DeckSyncWriter {
  /// ★★ 1 フィールドも変えずに書く（**D144**）★★
  Future<void> saveReceived(Deck received, {required List<DeckEditOpRecord> ops});
}

/// ★★ 受信（★§32-6 の **24** / 決定 **D144**）★★
///
/// ★★ [syncOneDeck] が「相手が勝った」と言ったときにだけ呼ぶ ★★
/// ★**この口は★判定も解決もしない**（★★済んでいる★★）。★**書いて、★器に記録するだけである。**
///
/// ## ★★ ログを 1 件残すのは★解決が起きたときだけである（**D119-1**）★★
///
/// | [DeckSyncRemoteWins.reason] | ★ログ |
/// |---|---|
/// | [DeckSyncRemoteReason.resolved] | ★★**`resolveConflict` を 1 件**★★（**D119-1** ＝ 後-1） |
/// | [DeckSyncRemoteReason.remoteOnly] | ★★**1 件も残さない**★★（★★手元の編集ではない★★） |
///
/// ★**残すと★★次の同期が「まだ送っていない編集が在る」と読む★★**（★候補 G の見る量である）。
///
/// ## ★★ 器は★書いたあとに記録する ★★
///
/// ★**目印は★★書いたあとの★★値を取る** —— ★`resolveConflict` の行が★★目印の内側に入る★★ため。
/// ★**外に置くと★★その 1 件を「まだ送っていない」として★次の同期が送る★★。**
///
/// ★★ 書いたあとに器の記録が失敗したら（★隠さない）★★
/// ★**手元は新しく、★器は古いままになる。**
/// → ★**次の同期は★もう一度同じものを受け取って★同じものを書く**（★★同じ結果になる★★）。
/// ★★**1 つのトランザクションにしていない**★★ —— ★**器は `loveca_db` の別の DAO で、
/// ★★この層は新しいトランザクションを 1 つも開かない★★**（`DeckRepository.save` の doc と同じ線 / **D55**）。
Future<void> applyRemoteDeck(
  DeckSyncRemoteWins outcome, {
  required DeckSyncWriter writer,
  required DeckSyncMarks marks,
  required DateTime at,
}) async {
  final ops = <DeckEditOpRecord>[
    if (outcome.reason == DeckSyncRemoteReason.resolved)
      (kind: DeckEditOpKind.resolveConflict, at: at),
  ];

  await writer.saveReceived(outcome.remote, ops: ops);

  final logMark = await marks.latestLogMark(outcome.remote.deckId);
  await marks.record(
    deckId: outcome.remote.deckId,
    logMark: logMark,
    baselineHash: deckContentHash(outcome.remote),
  );
}

/// ★★ `loveca_db` の DAO を [DeckSyncMarks] に嵌める（★★橋渡しだけ★★）★★
///
/// ★★ 判断を 1 つも持たない ★★
/// ★**3 つのメソッドを★そのまま通す。**★**この層で条件を足さない**（★足すと★試験の外に出る）。
class DeckSyncMarkDaoMarks implements DeckSyncMarks {
  const DeckSyncMarkDaoMarks(this._dao);

  final DeckSyncMarkDao _dao;

  @override
  Future<DeckSyncBaseline?> baselineFor(String deckId) =>
      _dao.baselineFor(deckId);

  @override
  Future<int> latestLogMark(String deckId) => _dao.latestLogMark(deckId);

  @override
  Future<void> record({
    required String deckId,
    required int logMark,
    required String baselineHash,
  }) =>
      _dao.record(
        deckId: deckId,
        logMark: logMark,
        baselineHash: baselineHash,
      );
}
