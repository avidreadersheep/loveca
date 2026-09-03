/// ★★ Android の画面の構成 —— ★★下段タブ 3 つ★★（`docs/Android UI 決定.md` §3-1 / ★**W-100**）★★
///
/// ★★ なぜ Windows と別の割り方なのか ★★
/// ★**Windows は 2 ペイン**（★一覧 ＋ デッキ ＋ 検証パネルを★同時に出す / **D61**）。
/// ★**電話は 411 論理px** で、★★しきい値 840 を大きく下回る★★ので★★1 ペインになる★★（★§3-1）。
/// → ★**同じ `PaneScaffold` に載せない。★★別の入れ物である★★。**
///
/// ★★ 「新商品」は落とす（★§3-1）★★
/// ★**WS の 4 つ目のタブに当たるものを★置かない**（★★個人利用なので新弾告知は要らない★★）。
///
/// ★★ この層が★決めないもの ★★
/// ★**1)** ★★中身★★ —— ★3 つとも★呼び出し側から受け取る（★★この層は 1 つも作らない★★）。
/// ★**2)** ★**どのタブから始めるか** —— ★★`initialIndex` で受け取る★★（★§3-1 は述べていない）。
/// ★**3)** ★**タブの絵** —— ★★選ばない★★（★§3-1 は★★字面しか述べていない★★ / **D-28**）。
///
/// ★★ 呼ぶ側は★今日 1 つも無い（**D-20** を承知で置く）★★
/// ★**`main.dart` は★Windows の入れ物を出す**（★★プラットフォームで分ける判断は★この層の論点ではない★★）。
/// ★**入るのは★★`docs/Android UI 決定.md` §19 の残りが片づいた日★★である。**
library;

import 'package:flutter/material.dart';

/// ★下段タブの並び（★★正はここ 1 か所★★ / ★§3-1 の絵と同じ順）。
///
/// ★★ 字面を画面にも試験にも書き写さない ★★
/// ★**書き写すと★★2 か所になる★★**（**D-15** の規約 3）。
const List<String> kAndroidTabLabels = <String>[
  'カード検索',
  'デッキ構築',
  'その他',
];

/// ★Android の入れ物（★§3-1）。
class AndroidHomePage extends StatefulWidget {
  const AndroidHomePage({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
  });

  /// ★3 つの中身（★★[kAndroidTabLabels] と同じ順・同じ数★★）。
  final List<Widget> tabs;

  /// ★最初に出すタブ。
  final int initialIndex;

  @override
  State<AndroidHomePage> createState() => _AndroidHomePageState();
}

class _AndroidHomePageState extends State<AndroidHomePage> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    assert(
      widget.tabs.length == kAndroidTabLabels.length,
      '★タブの数は ${kAndroidTabLabels.length} 本である（★§3-1）',
    );
    return Scaffold(
      // ★★ 木を捨てない ★★
      //   ★**`IndexedStack` は★見えていないタブの状態を★★保つ★★。**
      //   ★**切り替えるたびに作り直すと★★スクロール位置も入力中の字も消える★★。**
      body: IndexedStack(
        key: const ValueKey('androidHome:body'),
        index: _index,
        children: widget.tabs,
      ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('androidHome:tabs'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: <Widget>[
          for (var i = 0; i < kAndroidTabLabels.length; i++)
            NavigationDestination(
              key: ValueKey('androidHome:tab:$i'),
              // ★★ 絵を選ばない ★★
              //   ★**§3-1 は★★字面しか述べていない★★**（★**推測で埋めない** / **D-28**）。
              //   ★**`NavigationDestination` は `icon` を必須にするので★★中身の無い箱を渡す★★。**
              icon: const SizedBox.shrink(),
              label: kAndroidTabLabels[i],
            ),
        ],
      ),
    );
  }
}
