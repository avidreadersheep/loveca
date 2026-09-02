// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_identity_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncIdentityDaoMixin on DatabaseAccessor<LovecaDatabase> {
  $SyncIdentitiesTable get syncIdentities => attachedDatabase.syncIdentities;
  SyncIdentityDaoManager get managers => SyncIdentityDaoManager(this);
}

class SyncIdentityDaoManager {
  final _$SyncIdentityDaoMixin _db;
  SyncIdentityDaoManager(this._db);
  $$SyncIdentitiesTableTableManager get syncIdentities =>
      $$SyncIdentitiesTableTableManager(
        _db.attachedDatabase,
        _db.syncIdentities,
      );
}
