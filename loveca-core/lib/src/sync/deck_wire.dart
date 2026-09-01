/// ★★ 同期で運ぶ字面 —— ★組み立てと★★読み取り★★（決定 **D142** / 2026-09-02）★★
///
/// ★★ この節が閉じた門 ★★
/// ★**D116-2** の理由 3 が「★★受け取った内容から `Deck` を組む手段は決まっていない★★」と書き、
/// ★`docs/同期設計メモ.md` §4 が **D-14** の残り半分としてそれを持っていた。
/// → ★**§32-6 の **23** の配線と **24**（受信）が★2 つともこの門で止まっていた。**
///
/// ---
///
/// # ★★ 何を運ぶか —— `Deck.toJson()` の字面（★形-1）★★
///
/// | 案 | ★なぜ採らないか |
/// |---|---|
/// | ★**形-2 共有形式**（[Deck.toShareFormat]） | ★★**要求を満たさない**★★ —— ★`cardNumber` と枚数しか持たず、
///   ★★`deckId` も `updatedAt` も `memo` も `tags` も落ちる★★。★**解決（[resolveDeckConflict]）が★★立たない★★** |
/// | ★**形-3 同期専用の新しい形** | ★**版を 1 つ増やす**（★★`Deck.toJson` と★2 つの形を保つことになる★★）。
///   ★**得るものが 1 つも無い**（★[Deck.toJson] は★★12 フィールドをすべて持つ★★） |
///
/// ★★**形-1 は★決定性を持つ**★★ —— ★`Deck.toJson` は★★鍵を固定の順で書き、★Dart の `Map` は入れた順を覚える★★。
/// → ★**同じ `Deck` からは★★同じ字面が出る★★**（★対で固定した）。
/// ★★**ただし★これは印（`deckContentMark`）の正しさの前提ではない**★★ ——
/// ★**印はサーバーが★★保管している字面★★から作る**（**D141-1**）ので、★★組み立て直す必要が無い★★。
///
/// ---
///
/// # ★★ どう組むか —— ★★明示コンストラクタ（★組-1）★★
///
/// | 軸 | ★★**組-1 明示コンストラクタ（★採った）**★★ | ★組-2 `Deck.fromJson` をそのまま | ★組-3 `copyWith` で既存に重ねる |
/// |---|---|---|---|
/// | ★**(甲) 欠けた鍵** | ★★**断る**★★ | ★★**既定値で埋める**★★（★推測で埋める） | —— |
/// | ★**(乙) 手元に無いデッキ** | ★受け取れる | ★受け取れる | ★★**受け取れない**★★（★重ねる相手が無い） |
/// | ★**(丙) `Deck` に列が増えたとき** | ★★**コンパイルが止まる**★★ | ★★**黙って既定値になる**★★ | ★同左 |
/// | ★**(丁) 鍵の字面を 2 か所に持つか** | ★★**持つ**★★（★代償） | ★持たない | ★持たない |
///
/// ★★**組-3 は「劣る」のではない。★★要求を満たさない★★**★★ ——
/// ★**初回の受信では★★重ねる相手が手元に無い★★**（★§32-6 の 24 が★まさにその場面である）。
/// ★**`copyWith` は `deckId` / `createdAt` / `masterDataVersion` の引数を持たない**ので、
/// ★★相手の値を 1 つも運べない★★。
///
/// ★★**組-2 は★(甲) で落ちる。★好みではない**★★ ——
/// ★[Deck.fromJson] は★★`memo` が無ければ空文字、★`entries` が無ければ空の列、★`revision` が無ければ 0★★にする。
/// → ★**壊れた字面が★★「空のデッキ」として★成立してしまう★★。**
/// → ★**そのまま [resolveDeckConflict] に渡すと、★★空のデッキが勝って★手元のデッキが消えうる★★。**
/// ★★**`Deck.fromJson` は 1 文字も書き換えない**★★（**D-35**）—— ★**あちらは★★手元のファイルを読む口である★★**
/// （★★寛容であることが★そこでは正しい★★ / **§7-7** —— ★同じ形でも★見ている相手が違う）。
///
/// ★★**(丁) の代償を隠さない**★★ —— ★**鍵の字面が★[Deck.toJson] と★ここの 2 か所に在る。**
/// → ★**走査で見張る**（`deck_wire_test.dart` —— ★★往復して 12 フィールドとも一致することを見る★★）。
///
/// ---
///
/// # ★★ 決めていないこと（★★倒さない★★）★★
///
/// | # | 何 | ★なぜ決めないか |
/// |---|---|---|
/// | ★**1** | ★**版が違う端末どうしの読み書き** | ★**N-12** の相手である（★★入口は **D127-4** が足した★★）。★**この口は★版を 1 つも持たない** |
/// | ★**2** | ★**受け取った `Deck` を★どう保存するか** | ★**D115-4** が決めている（★既存の `save` 1 本）。★**この口は★組むだけである** |
/// | ★**3** | ★**読めなかったときに★何を見せるか** | ★**§32-6 の **25** である**（★未着手）。★**この口は★投げる** |
library;

import 'dart:convert';

import '../entities/deck.dart';

/// ★[deck] を★同期で運ぶ字面にする（★形-1）。
///
/// ★★ 同じ `Deck` からは★同じ字面が出る ★★
/// ★**[Deck.toJson] が★鍵を固定の順で書く**ため（★対で固定した）。
String encodeDeckForSync(Deck deck) => jsonEncode(deck.toJson());

/// ★同期で受け取った [content] から [Deck] を組む（★組-1）。
///
/// ★★ 欠けた鍵は★断る。★埋めない ★★
/// ★**壊れた字面を★★「空のデッキ」として通すと、★解決で勝って★手元のデッキが消えうる★★。**
///
/// ★★ 投げる（★戻り値で分けない）★★
/// ★**「読めなかった」を★どう見せるかは★★§32-6 の 25 である★★**（★未着手）。
/// → ★**ここで★★答えを 3 つに分けない★★**（★**D137-3** と同じ判断 —— ★呼ぶ側が 1 つも無い）。
///
/// ★**投げるのは [FormatException] だけである**（★対で固定した）。
Deck decodeDeckForSync(String content) {
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    throw const FormatException('★同期で受け取った字面が JSON ではない');
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('★同期で受け取った字面が表ではない');
  }

  return Deck(
    deckId: _string(decoded, 'deckId'),
    name: _string(decoded, 'name'),
    entries: _entries(decoded),
    memo: _string(decoded, 'memo'),
    tags: _tags(decoded),
    coverPrintingId: _nullableString(decoded, 'coverPrintingId'),
    createdAt: _time(decoded, 'createdAt'),
    updatedAt: _time(decoded, 'updatedAt'),
    deletedAt: _nullableTime(decoded, 'deletedAt'),
    revision: _int(decoded, 'revision'),
    lastDeviceId: _string(decoded, 'lastDeviceId'),
    masterDataVersion: _int(decoded, 'masterDataVersion'),
  );
}

/// 鍵が無い / 型が違う / 空 —— ★どれも断る。
String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('★$key が文字列でない（★鍵が無い場合を含む）');
  }
  return value;
}

/// ★`null` は許すが、★鍵そのものが無いのは断る（★★「無い」と「空」を分ける★★）。
String? _nullableString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('★$key の鍵そのものが無い');
  }
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('★$key が文字列でも null でもない');
  }
  return value as String?;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('★$key が整数でない（★鍵が無い場合を含む）');
  }
  return value;
}

DateTime _time(Map<String, Object?> json, String key) {
  final raw = _string(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null) {
    throw FormatException('★$key が日時として読めない');
  }
  return value;
}

DateTime? _nullableTime(Map<String, Object?> json, String key) {
  final raw = _nullableString(json, key);
  if (raw == null) return null;
  final value = DateTime.tryParse(raw);
  if (value == null) {
    throw FormatException('★$key が日時として読めない');
  }
  return value;
}

List<String> _tags(Map<String, Object?> json) {
  final raw = json['tags'];
  if (raw is! List<Object?>) {
    throw const FormatException('★tags が列でない（★鍵が無い場合を含む）');
  }
  final out = <String>[];
  for (final tag in raw) {
    if (tag is! String) throw const FormatException('★tags の値が文字列でない');
    out.add(tag);
  }
  return out;
}

List<DeckEntry> _entries(Map<String, Object?> json) {
  final raw = json['entries'];
  if (raw is! List<Object?>) {
    throw const FormatException('★entries が列でない（★鍵が無い場合を含む）');
  }
  final out = <DeckEntry>[];
  for (final entry in raw) {
    if (entry is! Map<String, Object?>) {
      throw const FormatException('★entries の要素が表でない');
    }
    out.add(DeckEntry(
      printingId: _string(entry, 'printingId'),
      count: _int(entry, 'count'),
    ));
  }
  return out;
}
