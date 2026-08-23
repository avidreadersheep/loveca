/// リポジトリの例外（`docs/UI設計メモ.md` §3-5(1)）.
///
/// ★★ isolate 境界で失われる「どこで起きたか」を補うためにある ★★
/// drift の executor は別 isolate（決定 D45）で走るため、背景 isolate の例外は
/// `Future` のエラーとして返るが、**スタックトレースは境界で切れる**
/// （呼び出し側のトレースが付く）。
/// どの操作で起きたかを [op] に載せて包み直す。
///
/// ★★ 例外を握るためのものではない ★★
/// `catch` して空リストを返す経路を作らないこと（決定 D53）。
/// **「空」と「失敗」を同じ型で表さない。** Store が [Failed] へ写す。
library;

class RepositoryException implements Exception {
  RepositoryException({
    required this.op,
    required this.cause,
    required this.causeStackTrace,
  });

  /// どの操作か（例: `cardList.load`）。
  final String op;

  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() => 'RepositoryException($op): $cause';
}

/// [body] の失敗を [RepositoryException] に包む。
Future<T> guardRepository<T>(String op, Future<T> Function() body) async {
  try {
    return await body();
  } on RepositoryException {
    // 二重に包まない。
    rethrow;
  } on Object catch (error, stackTrace) {
    throw RepositoryException(
      op: op,
      cause: error,
      causeStackTrace: stackTrace,
    );
  }
}
