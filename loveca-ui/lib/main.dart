/// エントリポイント。★`runApp` だけ（`docs/UI設計メモ.md` §8）。
///
/// 技術検証は `spike/` の下にある。`spike/` は本実装と混ざらないよう `lib/` の外に
/// 置いてあり、`lib/` からは参照しない（決定 D51）。
library;

import 'package:flutter/material.dart';

import 'src/app.dart';

void main() => runApp(const LovecaApp());
