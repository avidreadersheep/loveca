/// アプリの器（`docs/UI設計メモ.md` §2-2 / §8）.
///
/// ★R1 起動ゲートを通してから画面を出す。`AppScope` の設置は `BootGate` が行う。
/// ★M1 のホームは R4（カード閲覧）。R2（デッキ一覧）は M2 なので、それまでの暫定。
library;

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'boot/boot_gate.dart';
import 'boot/boot_steps.dart';
import 'ui/browse/card_browse_page.dart';

class LovecaApp extends StatelessWidget {
  const LovecaApp({super.key, this.steps});

  /// 差し替え用（テスト）。既定は本番の 4 段。
  final BootSteps? steps;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ラブカ シミュレーター',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: BootGate(
          steps: steps ?? RealBootSteps(appVersion: AppInfo.version),
          // ★M2 で R2（デッキ一覧）に差し替える。
          builder: (_) => const CardBrowsePage(),
        ),
      );
}
