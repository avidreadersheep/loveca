/// Android の警告の文言（`docs/Android UI 決定.md` §3-17）.
///
/// ★★ 命令形で統一する（§3-17）★★
///
/// | # | ★文言 |
/// |---|---|
/// | ★**1** | ★「**メンバーカードは 48 枚にしてください。**」 |
/// | ★**2** | ★「**ライブカードは 12 枚にしてください。**」 |
/// | ★**3** | ★「**エネルギーカードは 12 枚にしてください。**」（★★1〜11 枚のときだけ★★ / §1-1） |
/// | ★**4** | ★「**LL-bp1-001「日野下花帆」は 4 枚までです。**」 |
/// | ★**5** | ★「**LL-bp1-001-P のカードが見つかりません。**」（★★命令形にしない★★） |
///
/// ★★ 5 だけ命令形にしない理由（§3-17）★★
/// ★**マスタから消えたカードなので★★カード名が引けず★★、
/// ★利用者が何をすべきかも★★状況で変わる★★**（★取り除くのか、★カードデータを更新するのか）。
/// ★**決定 **D35** が「黙って削除しない」と定めているので、★★アプリが勝手に消すことはできない★★。**
///
/// ★★ カードの名指しは「カードナンバー ＋（カード名）」（§3-17）★★
/// ★★**「同名カード」という言い方は使えない**★★ ——
/// ★**カード名が同じでもカードナンバーが違えば★★別カード★★**（★制限は別々に掛かる）、
/// ★**同じカードナンバーの★★別の刷り★★は同名**（★制限は★★合算される★★）。
/// → ★**この層は★★その語を 1 度も出さない★★**（★対で固定した）。
///
/// ★★ 数は `RuleConfig` から来る。★字面で書かない ★★
/// ★**48 / 12 / 12 / 4 は★★`DeckIssue.expected` に入っている★★**
/// （★`DeckValidator` が `RuleConfig` から詰めている / ★実読）。
///
/// ★★ 作法（★実装メモ §9-5 / M3）★★
/// ★**内部語彙を出さない**（★対で固定した ＝ ★★列挙の名前が 1 つも出ない★★）／
/// ★**1 件 = 1 行**（★対で固定した ＝ ★★改行を 1 つも含まない★★）／ ★**対処まで書く**。
///
/// ★★ `DeckIssue.message` を使わない。★理由を書く ★★
/// ★**あちらは★★Windows の文言である★★**（★「メンバーカード 45枚 (48枚ちょうど必要)」）。
/// ★★**命令形ではなく、★内部の言い方も混ざる**★★（★「パラレル違いも合算されます」）。
/// → ★**`loveca_core` を 1 行も変えずに、★★この層で書き直す★★**
/// （★★同期にもサーバーにも 1 ビットも影響しない★★ / **D28**）。
library;

import 'package:loveca_core/loveca_core.dart';

/// カードナンバーからカード名を引く口。
///
/// ★★ カタログを引かない ★★
/// ★**呼び出し側から受け取る**（★★U21 の論点 1 に 1 ミリも触らない★★ /
/// ★先例は `card_list_tile.dart` / `deck_stats_section.dart`）。
typedef CardNameLookup = String? Function(String cardNumber);

/// [issue] 1 件ぶんの文言（★★1 行★★ / §3-17）。
String androidDeckWarningOf(DeckIssue issue, {CardNameLookup? nameOf}) {
  switch (issue.code) {
    // ★★ 1 / 2 / 3 —— ★命令形（§3-17）★★
    //   ★数は `expected` から来る（★字面で書かない）。
    case DeckIssueCode.memberCountMismatch:
      return 'メンバーカードは ${issue.expected} 枚にしてください。';
    case DeckIssueCode.liveCountMismatch:
      return 'ライブカードは ${issue.expected} 枚にしてください。';
    case DeckIssueCode.energyCountMismatch:
      return 'エネルギーカードは ${issue.expected} 枚にしてください。';
    // ★★ 4 —— ★カードナンバー ＋（カード名）（§3-17）★★
    case DeckIssueCode.tooManyCopies:
      final number = issue.cardNumber ?? '';
      final name = nameOf?.call(number);
      // ★★ 名前が引けなければ★番号だけを出す（★既定値）★★
      //   ★**§3-17 は★★引けない場合を述べていない★★**。
      //   ★★**推測で括弧を空にしない**★★（★「LL-bp1-001「」は」になる）。
      //   ★★**助詞の前の空白も★分けている**★★ —— ★§3-17 の字面は
      //   ★★閉じ括弧のあとに空白を置いていない★★（★番号だけのときは置く）。
      final named = name == null ? '$number は' : '$number「$name」は';
      return '$named ${issue.expected} 枚までです。';
    // ★★ 5 —— ★命令形にしない（§3-17 / ★理由は上の doc）★★
    case DeckIssueCode.unknownPrinting:
      return '${issue.printingId ?? issue.cardNumber ?? ''} のカードが見つかりません。';
    // ★★ §3-17 は★この 1 つを挙げていない。★既定値である ★★
    //   ★**命令形にしない** —— ★★5 とまったく同じ理由である★★
    //   （★何をすべきかが★状況で変わる）。
    case DeckIssueCode.invalidCount:
      return '${issue.printingId ?? ''} の枚数が正しくありません。';
  }
}

/// 画面に出す文言の列。
///
/// ★★ どの issue を出すかは [visibleDeckIssues] が決める（§1-1）★★
/// ★**ここでは★★1 件も落とさない★★**（★★出し分けを 2 か所に置かない★★ / **D-15** の規約 3）。
List<String> androidDeckWarnings(
  Iterable<DeckIssue> issues, {
  CardNameLookup? nameOf,
}) =>
    [
      for (final issue in issues) androidDeckWarningOf(issue, nameOf: nameOf),
    ];
