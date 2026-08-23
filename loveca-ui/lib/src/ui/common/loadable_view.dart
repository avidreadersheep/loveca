/// `Loadable<T>` を描く唯一の口（決定 D53 / `docs/UI設計メモ.md` §3-4(1)）.
///
/// ★★ `Failed` を既定でエラー表示する ★★
/// 握り潰すには `onError` を**明示的に書く**必要がある。
/// つまり握り潰しはレビューで見える。
///
/// パッケージを入れない選択（決定 D53）は「非同期の状態遷移を自前で書く」ことを
/// 意味するので、その定型をここ 1 箇所に寄せる。
library;

import 'package:flutter/material.dart';

import '../../state/store.dart';

class LoadableView<T> extends StatelessWidget {
  const LoadableView({
    super.key,
    required this.loadable,
    required this.ready,
    this.loading,
    this.onError,
  });

  final Loadable<T> loadable;
  final Widget Function(T value) ready;
  final WidgetBuilder? loading;

  /// ★渡さなければエラーが出る。握り潰すにはここに明示的に書くこと。
  final Widget Function(Object error, StackTrace stackTrace)? onError;

  @override
  Widget build(BuildContext context) => switch (loadable) {
        Loading<T>() =>
          loading?.call(context) ?? const _DefaultLoading(),
        Failed<T>(:final error, :final stackTrace) =>
          onError?.call(error, stackTrace) ?? _DefaultError(error: error),
        Ready<T>(:final value) => ready(value),
      };
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
}

/// ★既定でエラーを出す。空の一覧にすり替えない。
/// 「空」と「失敗」を同じ見た目にすると、利用者は「そのカードは無い」と誤解する。
class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            SelectableText('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
