/// ★★ 本番コードのカード番号リテラルが増えないこと（決定 D97）★★
///
/// D97 以前、3 パッケージの `lib/` に**カード番号のハードコードは 0 件**だった。
/// D97 で `AppSettings` の既定値が **1 箇所目**になる。★**例外はこれだけである。**
///
/// ★★ この検査は「手で走らせる grep」では足りない ★★
/// **D-2**（`loveca-core` にリントが 1 つも効いていなかった）が前例で、
/// **走らせる人がいなければ何も検知しない。**だからテストに置く。
///
/// ★★ カード番号そのものをこのファイルに書かない ★★
/// 走査対象は `lib` だけなので自己一致はしないが、
/// **同じものを 2 箇所に書けば必ず食い違う**（**D-15**）。
/// → `AppSettings.defaults.energyFillPrintingId` から**取り出す。**
/// ★もう 1 件（入力欄の見本）は**件数だけ**を見て、字面を書かない。
///
/// ★★ 陽性対照を対で置く ★★
/// 走査器が**実際に当たる**ことを先に確かめる。
/// 正規表現が壊れて 0 件になっていたら、下の「許可リストと一致」は
/// **「無い」ではなく「見えていない」**を意味する（**D-10** / `source_scan.dart` の戒め）。
///
/// ★★ 判定は「0 件」ではなく「許可リストと完全一致」★★
/// 0 件では書けない（既定値が 1 件あるため）。**3 件目が増えたら落ちる**形にする。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:path/path.dart' as p;

import '../support/source_scan.dart';

/// 走査する本番コード。★`test/` と `spike/` は含めない。
/// テストは fixture としてカード番号を持つのが正常で、
/// `spike/` は本実装ではない（**D51**）。
final _libRoots = <String>[
  'lib',
  coreLibPath,
  p.join('..', 'loveca-db', 'lib'),
];

/// ★許可リスト（ファイル名）。
///
/// | ファイル | なぜ許すか |
/// |---|---|
/// | `app_settings.dart` | ★**決定 D97 の既定値。**唯一の例外 |
/// | `deck_share_import_dialog.dart` | ★**入力欄の見本**（`hintText`）。カードを**解決する**用途ではない |
///
/// ★**この 2 つを混ぜて数えないこと。**格が違う。
const _allowedFiles = {'app_settings.dart', 'deck_share_import_dialog.dart'};

/// カード番号らしい文字列。
///
/// 実データの形（`LL-E-002` / `LL-bp1-001` / `PL!N-bp1-034-PE` /
/// `PL!HS-PR-013-PR` / `PL!SP-sd1-003`）から起こしてある。
/// ★先頭を大文字に限るので、日付（`2026-08-25`）や `utf-8` には当たらない。
final _cardNumberLike = RegExp(r'[A-Z][A-Za-z!]*-[A-Za-z0-9]+-[A-Za-z0-9+]+');

Map<String, List<String>> _scanAll() {
  final found = <String, List<String>>{};
  for (final root in _libRoots) {
    found.addAll(scanDartStringLiterals(root, _cardNumberLike));
  }
  return found;
}

void main() {
  group('★★ 陽性対照 —— 走査器が実際に当たること ★★', () {
    test('★既定値そのものがカード番号として当たる', () {
      // ★空文字なら下の検査は何も証明しない。
      expect(kDefaultEnergyFillPrintingId, isNotEmpty);
      expect(AppSettings.defaults.energyFillPrintingId,
          kDefaultEnergyFillPrintingId);
      expect(kDefaultEnergyFillPrintingId.contains(_cardNumberLike), isTrue,
          reason: '★正規表現が既定値に当たらないなら、走査は何も見ていない');
    });

    test('★★ コメントの中のカード番号は当たらない（対）★★', () {
      // ★`lib/` にはカード番号を説明として書いたコメントが実在する
      //   （書式の例示 / 幅の根拠 / 検索の説明）。**実行されないので数えない。**
      final literals = dartStringLiterals('''
// LL-bp1-002 x4
/// PL!N-bp1-034-PE
/* LL-E-002-SD */
const a = 'LL-E-999-SD';
''');

      expect(literals, ['LL-E-999-SD']);
    });

    test('★★ 日付や `utf-8` には当たらない（誤検知の対）★★', () {
      final literals =
          dartStringLiterals("const a = '2026-08-25'; const b = 'utf-8';");

      expect(literals.where((s) => s.contains(_cardNumberLike)), isEmpty);
    });

    test('★走査した根が 3 つとも実在する', () {
      // ★根の綴りを間違えると走査は静かに空を返し、下の検査が通ってしまう。
      for (final root in _libRoots) {
        expect(scanDartStringLiterals(root, RegExp('')), isNotEmpty,
            reason: '$root に .dart が 1 つも無い（綴り間違い？）');
      }
    });
  });

  test('★★ 本番コードのカード番号リテラルは許可リストと完全に一致する ★★', () {
    final found = _scanAll();

    expect(
      found.keys.toSet(),
      _allowedFiles,
      reason: '★増えていたら、それは本番コードに 3 件目のカード番号が入ったという意味である。\n'
          '  決定 D97 は「例外は既定値の 1 箇所だけ」と定めている。\n'
          '  種別からの導出（CardType.energy）か、利用者設定に置くこと。',
    );
  });

  test('★★ 既定値の 1 件は `app_settings.dart` のそれである ★★', () {
    // ★ファイル名が合っているだけでは足りない。**中身が既定値と同じ**であること。
    expect(_scanAll()['app_settings.dart'], [kDefaultEnergyFillPrintingId]);
  });

  test('★もう 1 件は入力欄の見本 1 つだけ（★字面はここに書かない）', () {
    expect(_scanAll()['deck_share_import_dialog.dart'], hasLength(1));
  });
}
