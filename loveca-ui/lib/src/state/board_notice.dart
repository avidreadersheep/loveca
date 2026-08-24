/// 盤面セッションの縮退・注記（`docs/UI設計メモ.md` §3-4(3) / 盤面設計メモ §10-3）.
///
/// ★★ 4 つ目の系統である。既存の 3 つに畳まない ★★
///
/// | その縮退の寿命 | 系統 | 出る場所 |
/// |---|---|---|
/// | 検索語ごと | `SearchDegradation` | 検索結果ヘッダ |
/// | 編集セッションごと | `DeckEditDegradation` | デッキペイン |
/// | 起動時に決まり以降不変 | `BootNotice` | R2 の `NoticeBar` |
/// | ★**盤面セッションごと（新設）** | **[BoardNotice]** | 盤面の帯 |
///
/// ★`sealed` を文脈ごとに分ける理由は網羅性検査である（決定 D53）。
/// まとめると、他の文脈に枝を足したときここにも「盤面では起きない」枝が生え、
/// **網羅性検査の意味が薄れる。**描画だけ `ui/common/degradation_line.dart` を共有する。
///
/// ★内部語彙（instanceId / printingId / reduce）を出さない。
library;

import 'package:loveca_core/loveca_core.dart';

sealed class BoardNotice {
  const BoardNotice();
}

/// ★★ 6.2.1.6（マリガン）がまだ無い（M-B5）★★
///
/// ★★ これは「中途半端に動くものを完成と誤認させない」ための表示である ★★
/// M-B1 の盤面は `GameSetup.begin` → `dealInitialEnergy` を続けて呼ぶので、
/// **マリガンを 0 枚として開始している**。条文の手順としては未完である。
///
/// ★M-B5 でマリガンを実装したら**この枝ごと消すこと。**
/// 残っていると「実装したのに出っぱなし」という無言の嘘になる。
final class MulliganNotImplemented extends BoardNotice {
  const MulliganNotImplemented();
}

/// デッキが 6.1 のデッキ構築条件を満たしていない。
///
/// ★★ それでも回せる。ただし黙って通さない ★★
/// アプリは「盤面・カード・山札・手札をデジタル上で操作するサンドボックス」
/// （CLAUDE.md §1 / D-A）なので、条件を満たさないデッキで回すこと自体は正当。
/// しかし**盤面から読み取れないと、あとで数が合わない理由が分からなくなる。**
///
/// ★開始ダイアログでも同じ内容を出して確認を取っている。ここは**盤面に残す**ぶん。
final class DeckNotValid extends BoardNotice {
  const DeckNotValid({required this.playerLabel, required this.issues});

  /// 「自分」/「相手」。★playerId を出さない（内部語彙）。
  final String playerLabel;

  /// `DeckValidator` が出した違反。★件数だけにしない（何が足りないか言えなくなる）。
  final List<DeckIssue> issues;
}
