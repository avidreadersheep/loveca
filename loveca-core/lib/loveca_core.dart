/// loveca_core — ラブカ シミュレーターのドメイン層.
///
/// ★ このパッケージは Flutter に一切依存させないこと ★
/// PC / スマホ / サーバの 3 者で共有される唯一の真実であり、
/// 単体テストの書きやすさとロジックの二重実装回避がプロジェクト全体の品質を決める。
library loveca_core;

export 'src/entities/card.dart';
export 'src/entities/deck.dart';
export 'src/entities/product.dart';
export 'src/master/master_data.dart';
export 'src/rules/deck_validator.dart';
