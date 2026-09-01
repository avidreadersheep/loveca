/// ★★ いま走っている機械の同定（★★分母と対で読む★★ / 2026-09-02 / ★運転指示【0】(1)）★★
///
/// ## ★★ 何のために在るか —— ★★1 つだけである★★ ★★
///
/// ★**分母**（`rate_limit.dart` の `measuredPasswordHashCostMs`）**は★★測った機械に依る★★。**
/// ★**次に測る人が「★★同じ機械か★★」を判定できないと、★★最大を採るのか置き換えるのかが決まらない★★**
///   （★理由の全文は `measuredPasswordHashCostMs` の doc の追記）。
/// → ★**この関数が★その判定の材料を作る。**
///
/// ## ★★ なぜ `rate_limit.dart` に置かないか ★★
///
/// ★**あちらは★★import を 1 つも持たない★★**（★純粋な定数と値の型だけ）。
/// ★**`dart:io` を足すと、★★上限の宣言が★実行環境に触れるようになる★★。**
/// → ★**記録した★★値★★はあちらに、★いま測る★★手段★★はこちらに置く。**
///
/// ## ★★ 一意には同定しない。★隠さない ★★
///
/// ★**同じ OS の版・同じコア数・同じ Dart の版の機械は★★区別できない★★**（**D-28**）。
/// ★**CPU の型も、★クロックも、★そのときの熱の状態も★★1 つも入っていない★★。**
/// → ★**書けるのは「★★字面が違えば★別の機械である★★」までである。★★逆は言えない★★。**
///
/// ## ★★ ホスト名も利用者名も入れない ★★
///
/// ★**入れると★★リポジトリに個人の機械の名前が残る★★**（★この字面は定数として commit される）。
library;

import 'dart:io';

/// いま走っている機械の同定。
///
/// ★★ 字面を★手で組み立てないための関数である ★★
/// ★**`tool/measure_hash_cost.dart` が出力し、★`test/rate_limit_test.dart` が突き合わせる。**
/// ★★**2 か所が★同じ関数を通る**★★（★★別々に組み立てると★★食い違っても分からない★★ / **D126-3** の代償を作らない）。
String currentMachineFingerprint() => '${Platform.operatingSystem} / '
    '${Platform.operatingSystemVersion} / '
    '${Platform.numberOfProcessors} コア / '
    'Dart ${_dartVersion()}';

/// `Platform.version` は★★ビルド日時を含む長い字面である★★。
///
/// ★**`3.11.1 (stable) (Tue Feb 24 ...) on "windows_x64"` の形**（★実測）。
/// → ★**版と対象だけを取り出す**（★★日時は★同じ SDK でも同じなので落としても判定は変わらない★★
///   —— ★★ただし「落としたこと」で★区別できない機械が増えることは無い★★）。
String _dartVersion() {
  final raw = Platform.version;
  final ver = raw.split(' ').first;
  final on = raw.indexOf(' on "');
  final target = on < 0 ? '' : raw.substring(on + 5, raw.length - 1);
  final channel = RegExp(r'\((stable|beta|dev)\)').firstMatch(raw)?.group(1);
  return '$ver${channel == null ? '' : ' ($channel)'}'
      '${target.isEmpty ? '' : ' $target'}';
}
