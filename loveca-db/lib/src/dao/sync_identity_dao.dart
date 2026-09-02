import 'package:drift/drift.dart';

import '../schema/database.dart';
import '../schema/tables.dart';

part 'sync_identity_dao.g.dart';

/// いま誰として、★どの端末として繋いでいるか（★★決定 **D125-2** ＝ 帰-2 ＋ **D145-3** ＝ 置-1★★）。
///
/// ★★ この DAO は★`sync_identities` の 1 行しか触らない ★★
/// ★**`decks` も `deck_entries` も `deck_edit_ops` も `deck_sync_marks` も★★1 度も読まない★★。**
/// ★**先例は [DeckSyncMarkDao]**（★同じ形 —— ★★器だけを触る★★）。
///
/// ★★ 2 つを★別々に書ける口を作らない ★★
/// ★**[record] は★利用者名と端末の同定を★★2 つとも必須で受ける★★。**
/// → ★★**片方だけ在る状態を★`lib` から作れない**★★（★規約ではなく★形で守る / **D115-5**）。
/// → ★**その結果、★★残-1（行の物理削除）と 残-2（DB ごと作り直す）が★同じ結果になる★★**
///   （**D125-3** を★先に決めてしまわない / `SyncIdentities.deviceId` の doc）。
///
/// ★★ 中途の状態を★呼ぶ側に見せない ★★
/// ★**v6 から移行してきた行は `device_id` が null である**（★移行は値を作らない）。
/// ★**[current] は★★その行を「まだ名乗っていない」として畳む★★**ので、
///   ★★呼ぶ側は★null の `device_id` を 1 度も受け取らない★★。
@DriftAccessor(tables: [SyncIdentities])
class SyncIdentityDao extends DatabaseAccessor<LovecaDatabase>
    with _$SyncIdentityDaoMixin {
  SyncIdentityDao(super.db);

  /// いまの同定（★★行が無ければ / ★中途なら `null`★★）。
  ///
  /// ★★ `null` は「まだ名乗っていない」である（**D114-3** と同じ形）★★
  /// ★**行の不在**と、★**`device_id` が null の行**の★★2 つを同じ答えに畳む★★ ——
  /// ★**呼ぶ側にとって★どちらも「名乗り直すところから」だからである。**
  Future<SyncIdentity?> current() async {
    final row = await (select(syncIdentities)
          ..where((t) => t.id.equals(0)))
        .getSingleOrNull();
    if (row == null) return null;
    final deviceId = row.deviceId;
    if (deviceId == null) return null;
    return (userName: row.userName, deviceId: deviceId);
  }

  /// 名乗る（★★利用者名と端末の同定を★同じ行に書く★★）。
  ///
  /// ★★ `id` を★明示する ★★
  /// ★**`INTEGER PRIMARY KEY` は★★rowid の別名になり、★DEFAULT が無視される★★**
  /// （★`SyncIdentities` の doc の実測）。→ ★**省くと★`CHECK (id = 0)` で落ちる。**
  ///
  /// ★★ 置き換えである。★足さない ★★
  /// ★**1 台に複数のアカウントは同居しない**（**D124-1**）。
  Future<void> record({
    required String userName,
    required String deviceId,
  }) async {
    await into(syncIdentities).insertOnConflictUpdate(
      SyncIdentityRow(id: 0, userName: userName, deviceId: deviceId),
    );
  }

  /// 忘れる（★★行を消して「まだ名乗っていない」に戻す★★）。
  ///
  /// ★★ 2 つとも消える。★片方だけ残さない ★★
  /// ★**残すと、★★入り直したあとも★同じ端末として名簿に残る★★**
  /// （★**D125-1** が消そうとしたものと★同じ列の量である / `SyncIdentities.deviceId` の doc）。
  ///
  /// ★★ この口は★`decks` を 1 行も触らない ★★
  /// ★**「前のアカウントのデッキを残さない」の手段は★★まだ決まっていない★★**（**D125-3**）。
  /// → ★**ここで一緒に消さない。★★決めていない分岐を先に置かない★★**（**D114-7** の理由 2）。
  Future<void> forget() async {
    await (delete(syncIdentities)..where((t) => t.id.equals(0))).go();
  }
}

/// [SyncIdentityDao.current] が返す値。
///
/// ★★ record にした —— ★★フィールドを 1 つ足すだけで増やせないため★★ ★★
/// ★**先例は `DeckEditOpRecord` / `DeckSyncBaseline`**（★★形が型である★★）。
typedef SyncIdentity = ({String userName, String deviceId});
