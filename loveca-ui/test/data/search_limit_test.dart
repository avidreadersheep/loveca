/// 検索上限の解釈（決定 D50 / D64）.
///
/// ★★ 不正値を黙って既定に戻さない ★★
/// 黙って戻すのは A-3（痕跡を残さずデータを落とす）と同じ型で、
/// 「下げたはずなのに打ち切られない」が原因不明のまま残る。
/// 戻したうえで**実値が残っている**ことをここで固定する。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/search_limit.dart';

void main() {
  test('既定は decision D50 の 2000', () {
    expect(SearchLimitSetting.standard.limit, CardSearchDao.defaultLimit);
    expect(CardSearchDao.defaultLimit, 2000);
  });

  group('未設定として扱う（警告しない）', () {
    for (final raw in [null, '', '   ']) {
      test(raw == null ? 'null' : '「$raw」', () {
        final setting = resolveSearchLimit(raw);
        expect(setting.limit, CardSearchDao.defaultLimit);
        expect(setting.isOverridden, isFalse);
        expect(setting.rejectedValue, isNull);
      });
    }
  });

  group('有効な上書き', () {
    test('50 を指定すると 50 になり、実値が残る', () {
      final setting = resolveSearchLimit('50');
      expect(setting.limit, 50);
      expect(setting.isOverridden, isTrue);
      expect(setting.overriddenValue, '50');
      expect(setting.rejectedValue, isNull);
    });

    test('前後の空白は落とす', () {
      expect(resolveSearchLimit(' 7 ').limit, 7);
    });

    test('1 は有効（境界）', () {
      expect(resolveSearchLimit('1').limit, 1);
      expect(resolveSearchLimit('1').isOverridden, isTrue);
    });

    test('既定より大きい値も通す（打ち切りを緩める向き）', () {
      expect(resolveSearchLimit('9999').limit, 9999);
    });
  });

  group('★不正値は既定に戻したうえで実値を残す', () {
    for (final raw in ['0', '-1', 'abc', '1.5', '２０', '']) {
      if (raw.isEmpty) continue;
      test('「$raw」', () {
        final setting = resolveSearchLimit(raw);
        expect(setting.limit, CardSearchDao.defaultLimit,
            reason: '既定に戻す');
        expect(setting.isOverridden, isFalse);
        // ★実値を捨てない。捨てると起動時に何を直せばよいか言えない。
        expect(setting.rejectedValue, raw);
      });
    }

    test('0 を弾く理由は「常に 0 件」と検索の故障が見分けられないから', () {
      expect(resolveSearchLimit('0').rejectedValue, '0');
    });
  });
}
