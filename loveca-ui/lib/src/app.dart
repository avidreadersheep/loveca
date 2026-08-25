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
///
/// ★★ `navigatorKey` を持つ理由（決定 D89）★★
/// 起動時の警告の帯は `BootGate` が **Navigator の上**に出す。
/// そこから「詳細」ダイアログを開き R6 へ飛ぶには、**下にある Navigator**が要る。
/// `MaterialApp.builder` の `context` は Navigator の**祖先**なので
/// `Navigator.of(context)` では届かない。鍵で辿る。
library;

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'boot/boot_gate.dart';
import 'boot/boot_steps.dart';
import 'ui/deck/deck_list_page.dart';

class LovecaApp extends StatefulWidget {
  const LovecaApp({super.key, this.steps});

  /// 差し替え用（テスト）。既定は本番の 4 段。
  final BootSteps? steps;

  @override
  State<LovecaApp> createState() => _LovecaAppState();
}

class _LovecaAppState extends State<LovecaApp> {
  /// ★決定 D89: 帯（Navigator の上）から Navigator を辿るための鍵。
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ラブカ シミュレーター',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        navigatorKey: _navigator,
        // ★起動ゲートを抜けるまで child（= Navigator）を組み立てない。
        //   Widget は遅延評価なので、返さない限り build されない。
        builder: (context, child) => BootGate(
          steps: widget.steps ?? RealBootSteps(appVersion: AppInfo.version),
          navigator: _navigator,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const DeckListPage(),
      );
}
