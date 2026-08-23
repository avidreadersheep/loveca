/// Phase 2 後半（UI 本実装）用のエントリポイント。
///
/// ★まだ実装しない★
/// 技術検証は `spike/` の下で行っている。`spike/` は本実装と混ざらないよう
/// `lib/` の外に置いてあり、`flutter run -t spike/main_grid.dart` のように
/// エントリポイントを指定して起動する。結果は `docs/UI技術検証メモ.md`。
library;

import 'package:flutter/material.dart';

void main() => runApp(const LovecaApp());

class LovecaApp extends StatelessWidget {
  const LovecaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ラブカ シミュレーター',
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Center(
            child: Text('本実装は Phase 2 後半。技術検証は spike/ を参照。'),
          ),
        ),
      );
}
