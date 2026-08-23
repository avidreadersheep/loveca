/// 時刻の供給元（`docs/UI設計メモ.md` §9-1 / 決定 D59〜D61 の周辺）.
///
/// `loveca_core` / `loveca_db` はどちらも**層の内側で `DateTime.now()` を呼ばない**設計で、
/// `DeckDao.softDelete(deckId, at)` / `MasterImporter.import(now:)` /
/// `MasterStateDao.recordIssue(at:)` はいずれも呼び出し側から受け取る。
/// その「呼び出し側」をここに 1 つ決める。
///
/// ★★ UI 層で `DateTime.now()` を書いてよいのは [systemClockUtc] の 1 行だけ ★★
/// 利得は 2 つ。
/// 1. テストで固定時刻を入れられる（`revision` と `updatedAt` の検証が決定的になる）
/// 2. `DateTime.now()` の grep が 1 箇所に収まるので、CLAUDE.md §1 の既知違反
///    （`Deck.copyWith` の `updatedAt` 既定値）を UI 側から踏んでいないことを確認できる
library;

typedef Clock = DateTime Function();

/// ★UI 層で `DateTime.now()` を書く唯一の場所。
DateTime systemClockUtc() => DateTime.now().toUtc();
