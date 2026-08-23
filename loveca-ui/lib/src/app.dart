/// アプリの器（`docs/UI設計メモ.md` §2-2 / §8）.
///
/// ★R1 起動ゲートを通してから画面を出す。`AppScope` の設置は `BootGate` が行う。
///
/// ★★ ホームはデッキ一覧（R2）である（§2-2）★★
/// アプリの目的がデッキ構築だから。M1 では R2 がまだ無かったので R4（カード閲覧）を
/// 暫定のホームにしていたが、M2 で本来の構成に戻した。
/// R4 へは R2 の AppBar から入る。
///
/// ★★ `AppScope` は Navigator より**上**に置く ★★
/// `home: BootGate(...)` にすると `AppScope` が Navigator の**下**に入り、
/// **`push` した画面（R3 / R4）から `AppScope.of` が届かない。**
/// M1 は画面が 1 枚で遷移が無かったため表面化しなかった。
/// `MaterialApp.builder` は Navigator を `child` として受け取るので、
/// ここで包めば全ルートから見える。
library;

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'boot/boot_gate.dart';
import 'boot/boot_steps.dart';
import 'ui/deck/deck_list_page.dart';

class LovecaApp extends StatelessWidget {
  const LovecaApp({super.key, this.steps});

  /// 差し替え用（テスト）。既定は本番の 4 段。
  final BootSteps? steps;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ラブカ シミュレーター',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        // ★起動ゲートを抜けるまで child（= Navigator）を組み立てない。
        //   Widget は遅延評価なので、返さない限り build されない。
        builder: (context, child) => BootGate(
          steps: steps ?? RealBootSteps(appVersion: AppInfo.version),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const DeckListPage(),
      );
}
