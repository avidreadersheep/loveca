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
export 'src/game/aggregation.dart';
export 'src/game/card_instance.dart';
export 'src/game/card_move.dart';
export 'src/game/energy_deck.dart';
export 'src/game/game_action.dart';
export 'src/game/game_setup.dart';
export 'src/game/game_state.dart';
export 'src/game/history.dart';
export 'src/game/member_area.dart';
export 'src/game/phase.dart';
export 'src/game/redact.dart';
export 'src/game/reduce.dart';
export 'src/game/refresh.dart';
export 'src/game/rng.dart';
export 'src/game/rule_process.dart';
export 'src/game/step.dart';
export 'src/game/step_engine.dart';
export 'src/game/turn_order.dart';
export 'src/game/zone.dart';
