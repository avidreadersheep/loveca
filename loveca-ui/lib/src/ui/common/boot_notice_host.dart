/// 起動時の警告を**全ルートの上**に出す（決定 D89 / `docs/UI設計メモ.md` §11-3）.
///
/// ★★ 置き場を 1 箇所に一本化する ★★
/// M1 では `NoticeBar` が R4（当時の暫定ホーム）の中にあり、**R4 だったから
/// 結果的に出ていただけ**だった。M2 でホームが R2 に移ったあと、
/// 帯は R2 にだけ移されて**同じ形の失敗が残った** ——
/// dist が解決できていないときの症状（カード画像が 1 枚も出ない）は
/// R3 / R4 / R7 で現れるのに、**原因はそこから読めない。**
///
/// → `BootGate` は `BootReady.notices` を持っている。**ここが唯一の 1 箇所である。**
/// 各ルートの `AppBar` にバッジを配る案は採らない ——
/// **忘れても何も壊れない**ので、新しいルートを足した人が必ず落とす
/// （D66 が「どちらに出すかを決めるのは 1 行だけ」と定めたのと同じ理由）。
///
/// ★★ これは「R2 から消す」ではなく「R2 だけに出ていたものを全画面に出す」★★
/// 消えるものが 1 つも無いことを `test/boot/boot_notice_bar_test.dart` が固定している。
///
/// ★★ `notices` が空なら何も足さない ★★
/// [NoticeBar] 自身が `SizedBox.shrink()` を返すので高さは 0 になるが、
/// **「増えないはず」で済ませない** —— M-B2 と M-B3 で「増やさないはず」が
/// 2 回とも実際に動いた（D83 / D86）。`board_min_width_test.dart` が実測している。
library;

import 'package:flutter/material.dart';

import '../../boot/boot_steps.dart';
import 'notice_bar.dart';

class BootNoticeHost extends StatelessWidget {
  const BootNoticeHost({
    super.key,
    required this.notices,
    required this.navigator,
    required this.child,
  });

  final List<BootNotice> notices;

  /// ★★ 帯は `Navigator` の**上**にあるので `Navigator.of(context)` が届かない ★★
  /// 「詳細」ダイアログと R6 への遷移にはこの鍵が要る（D89 の層 3）。
  final GlobalKey<NavigatorState> navigator;

  /// `MaterialApp.builder` が渡す `Navigator`。
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoticeBar(notices: notices, navigator: navigator),
          Expanded(child: child),
        ],
      );
}
