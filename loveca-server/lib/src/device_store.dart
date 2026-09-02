/// ★★ 端末の名簿 —— ★★利用者 1 人につき JSON のファイル 1 つ★★（★§32-6 の **26** / 決定 **D145**）★★
///
/// ## ★★ 何のために在るか ★★
///
/// ★**D117-1** が「★すべての端末が受け取ったことを確かめてから捨てる」と決め、
/// ★**N-19** が「★★集合から抜ける手段が無いと、★捨てる規則は 1 度も発火しない★★」と書いた。
/// → ★**この名簿が★その集合である。**
///
/// ★★**ただし★ログを捨てる規則そのものは★今日 1 行も無い**★★（**D116-6** / **Q-10**）——
/// ★**§77-2 が「★★確かめる対象が★実装に存在しない★★」と測った分である。**
/// → ★**この名簿が★★いま実際に果たすのは★★引き金★★である**（**D145-2** ＝ 引-1）。
///
/// ## ★★ 外す判断は★ここが持つ（**D145-1** ＝ 判-1）★★
///
/// ★**観測（「この端末はこれだけのあいだつながっていない」）は★★サーバーにしかできない★★**
/// （§30-9 —— ★端末どうしは直接つながらない / **D105-1**）。
/// ★**判断も★ここに置く** —— ★**端末に配ると★★時計のずれで★端末ごとに答えが割れる★★**
/// （**D108-2** の (i)）。★**先例は **D138-1** の 同-1**（★収束しないものは★★要求を満たさない★★）。
///
/// ## ★★ 「新しい端末」と「外れて戻ってきた端末」を★区別しない（**D145-2**）★★
///
/// ★**返すのは「★★名簿に居たか★★」の 1 ビットだけである。**
/// ★**§27-4 が「★外された端末にとって『捨てられた』は『失った』と区別がつかない」と書き、
/// ★**D121-7** が★★その理由で 落-1 を採った★★。**
/// ★**新しい端末では★器の行が★元から 0 件なので、★★落-1 は何も消さない★★。**
///
/// ★★**墓標を持たない。★隠さない**★★ —— ★**サーバー自身も★★2 つを区別できない★★。**
/// ★**持てば区別できる**（★★開き直す条件★★）が、★**今日それを要る場面が 1 つも無い**（★上の 2 行）。
///
/// ## ★★ 保管の形は★`DeckFileStore` と同じである（**D134-6** / **D134-7**）★★
///
/// ★**利用者 1 人につき JSON のファイル 1 つ。★★ファイル名は利用者名の SHA-256 の 16 進★★。**
/// ★**利用者名そのものは★ファイルの★中に持つ**（★戻せなくならないため）。
/// ★★**同型としてまとめない**★★（**§7-7**）—— ★**同じ形を採った理由は★★量が違うからではない★★**：
/// ★**名簿は★★端末の数だけ★★で、★同期のたびに 1 行だけ書き換わる**（★デッキと同じ性質）。
///
/// ## ★★ 期間は★呼び出し側から渡す（**N-19** の (2-b) は★利用者判断のまま）★★
///
/// ★**値は **D124-3**（10 日）である。★★誰が決めるかは返っていない★★**
/// （★問いは `docs/同期設計メモ.md` §30-7 / ★既定値は `docs/利用者への問い.md` の **Q-02**）。
/// → ★**この class は★値を持たない。★★差し替え点は呼び出し側の 1 引数である★★。**
///
/// ## ★★ 時刻も★呼び出し側から渡す（★時間を測る検査を作らない / **D-28**）★★
///
/// ★**`DateTime.now()` を 1 度も呼ばない** —— ★**待って測る検査は★機械の状態で揺れる。**
/// ★**先例は `RateLimiter`**（★`clock` を受け取る）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 保管しているファイルの版。
///
/// ★**アカウントの保管とも★デッキの保管とも★★別の版である★★。**
const int deviceFileVersion = 1;

/// ★★ 使わなくなった端末を外すまでの期間（★★既定値。★決定ではない★★）★★
///
/// ★**値は **D124-3**（★★10 日★★ / ★利用者が 2026-09-01 に答えた）。**
/// ★★**誰がどうやって決めるかは★返っていない**★★（**N-19** の (2-b) —— ★利用者判断のまま）。
/// ★**問いの文言は `docs/同期設計メモ.md` §30-7 / ★既定値と差し替え点は
///   `docs/利用者への問い.md` の **Q-02**。**
///
/// ★★ 差し替え点は★ここ 1 つである ★★
/// ★**口も保管も★★値を持たない★★**（★★どちらも引数で受け取る★★）。
const Duration defaultDeviceMaxIdle = Duration(days: 10);

/// 名簿を引いた結果。
///
/// ★★ 1 ビットしか返さない（**D145-2**）★★
/// ★**[wasKnown] が `false` なら、★呼ぶ側は★★器を戻す★★**（**D121-7** ＝ 落-1）。
/// ★**「新しい」か「外された」かは★★返さない。★区別していない★★。**
typedef DeviceTouchResult = ({bool wasKnown, List<String> deviceIds});

/// 端末の名簿の保管（★§32-6 の **26**）。
class DeviceFileStore {
  DeviceFileStore(this._dir);

  final Directory _dir;

  /// ★★ ファイル名は★利用者名の SHA-256 の 16 進（★柵 / **D134-7**）★★
  File _fileFor(String userName) {
    final digest = sha256.convert(utf8.encode(userName)).toString();
    return File('${_dir.path}${Platform.pathSeparator}$digest.json');
  }

  Map<String, DateTime> _readAll(String userName) {
    final file = _fileFor(userName);
    if (!file.existsSync()) return <String, DateTime>{};
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★保管の中身が表ではない');
    }
    if (decoded['version'] != deviceFileVersion) {
      throw FormatException('★知らない版: ${decoded['version']}');
    }
    final devices = decoded['devices'];
    if (devices is! Map<String, Object?>) {
      throw const FormatException('★devices が表ではない');
    }
    final rows = <String, DateTime>{};
    devices.forEach((deviceId, seen) {
      if (seen is! String) {
        throw const FormatException('★devices の値が文字列ではない');
      }
      rows[deviceId] = DateTime.parse(seen).toUtc();
    });
    return rows;
  }

  void _writeAll(String userName, Map<String, DateTime> rows) {
    if (!_dir.existsSync()) _dir.createSync(recursive: true);
    final file = _fileFor(userName);
    // ★★ 途中で落ちても元が残る（★アカウント / デッキの保管と同じ形）★★
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(jsonEncode({
      'version': deviceFileVersion,
      // ★★ 利用者名は★ここに持つ（★ファイル名からは戻せない）★★
      'userName': userName,
      'devices': {
        for (final e in rows.entries) e.key: e.value.toUtc().toIso8601String(),
      },
    }));
    temp.renameSync(file.path);
  }

  /// 名簿に触れる（★★古いものを外し、★この端末を今の時刻で記録する★★）。
  ///
  /// ## ★★ 外してから★見る。★順序が意味を持つ ★★
  ///
  /// ★**先に外さないと、★★自分自身が★古いまま「居た」と数えられる★★**
  ///   （★10 日以上ぶりに繋いだ端末が★★外れたことに気づけない★★）。
  /// → ★**対で固定した。**
  ///
  /// ## ★★ 自分を★除いて数えない ★★
  ///
  /// ★**[DeviceTouchResult.deviceIds] は★★書いたあとの名簿★★である**（★自分を含む）。
  /// ★**呼ぶ側が「全端末」を知るための量であり、★★自分も全端末の 1 つである★★。**
  ///
  /// ## ★★ 期間も時刻も★渡される ★★
  ///
  /// ★**[maxIdle] は **D124-3**（10 日）だが、★★誰が決めるかは未決である★★**（**Q-02**）。
  /// ★**[now] は★呼び出し側の時計** —— ★★この class は `DateTime.now()` を 1 度も呼ばない★★。
  ///
  /// ---
  ///
  /// ## ★★ 2026-09-02 追記: ★★[join] を足した（**D148-1** / ★運転指示【0】(4)）★★
  ///
  /// ★★**上の 4 節は 1 文字も書き換えない**★★（**D-35** —— ★★その時点で誤りではない★★）。
  /// ★**§80-4 が「★途中で落ちたときは★★自分で直らない★★」と記録した分である。**
  ///
  /// ★★ 何が変わったか —— ★★段 3 が★条件つきになった ★★
  /// ★**[join] が `false` のとき、★★名簿に居ない端末を★書き加えない★★。**
  /// ★**居る端末は★時刻を書き直す**（★★書き直さないと★10 日で外れる★★）。
  ///
  /// ★★ なぜ —— ★★呼ぶ側が★器を消してから★記録できるようにするためである ★★
  /// ★**旧は「★判定 ＋ 記録」が★1 つの要求で不可分だった**ので、
  ///   ★★記録のあとに器を消し損ねると★次の要求が `known: true` を返し、★器が古いまま残った★★。
  /// → ★**順序を「★問う → ★器を消す → ★記録する」に変えると、★★途中で落ちても
  ///   名簿が古いまま残り、★次の同期が★同じ経路を通る★★**（★冪等 / ★`device_client.dart` の doc）。
  ///
  /// ★★ [join] は★省けない ★★
  /// ★**口の側が★★鍵の不在を 400 で断る★★**（`device_endpoint.dart`）—— ★**既定を `false` に読むと、
  ///   ★★鍵を落とすだけで★端末が永久に名簿へ入れず、★同期のたびに器が消える★★**（★先例は **D141-4**）。
  DeviceTouchResult touch(
    String userName,
    String deviceId, {
    required DateTime now,
    required Duration maxIdle,
    required bool join,
  }) {
    final rows = _readAll(userName);

    // ★★ 段 1 —— ★★古いものを外す（**D145-1** ＝ 判-1）★★
    final cutoff = now.toUtc().subtract(maxIdle);
    rows.removeWhere((_, seen) => seen.isBefore(cutoff));

    // ★★ 段 2 —— ★★居たかを見る（★外したあとで見る）★★
    final wasKnown = rows.containsKey(deviceId);

    // ★★ 段 3 —— ★★今の時刻で記録する（**D148-1** ＝ ★条件つきになった）★★
    //   ★**居る端末は★必ず書き直す** —— ★★書き直さないと★10 日で外れる★★。
    //   ★**居ない端末は [join] のときだけ書き加える。**
    if (wasKnown || join) rows[deviceId] = now.toUtc();
    // ★★ 外した結果は★[join] に関わらず保存する（★段 1 は★本物の変化である）★★
    _writeAll(userName, rows);

    final ids = rows.keys.toList()..sort();
    return (wasKnown: wasKnown, deviceIds: ids);
  }

  /// 名簿を読むだけ（★★1 行も書かない★★ / ★試験と診断のため）。
  ///
  /// ★**外す判断も★しない** —— ★★[touch] だけが名簿を動かす★★。
  List<String> listDeviceIds(String userName) {
    final ids = _readAll(userName).keys.toList()..sort();
    return ids;
  }
}
