/// 一覧の絞り込みパネル（決定 D48 / `docs/UI設計メモ.md` §4-2）.
///
/// ★★ コスト絞り込みは種別がメンバーのときだけ出す ★★
/// `cost` はメンバーにしか値が無い（`normalize.py:362-363`）。
/// 種別を問わず出すと「コスト 2 以下」でライブとエネルギーが全部消え、
/// 利用者にはその理由が分からない（§4-2 の案 (a)）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/card_browse_store.dart';

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.store});

  final CardBrowseStore store;

  static const List<int> _costOptions = [0, 1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CardBrowseState>(
        valueListenable: store,
        builder: (context, state, _) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('絞り込み', style: theme.textTheme.titleMedium),
                  ),
                  if (state.isFiltered)
                    TextButton(
                      onPressed: store.clearFilter,
                      child: const Text('解除'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: state.filter.expansion,
                decoration: const InputDecoration(
                  labelText: '商品',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('すべて')),
                  for (final e in state.expansions)
                    DropdownMenuItem<String?>(value: e, child: Text(e)),
                ],
                onChanged: store.setExpansion,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CardType?>(
                initialValue: state.filter.cardType,
                decoration: const InputDecoration(
                  labelText: '種別',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem<CardType?>(child: Text('すべて')),
                  DropdownMenuItem<CardType?>(
                    value: CardType.member,
                    child: Text('メンバー'),
                  ),
                  DropdownMenuItem<CardType?>(
                    value: CardType.live,
                    child: Text('ライブ'),
                  ),
                  DropdownMenuItem<CardType?>(
                    value: CardType.energy,
                    child: Text('エネルギー'),
                  ),
                ],
                onChanged: store.setCardType,
              ),
              const SizedBox(height: 16),
              // ★★ メンバーのときだけ出す ★★
              if (state.filter.cardType == CardType.member) ...[
                DropdownButtonFormField<int?>(
                  initialValue: state.filter.maxCost,
                  decoration: const InputDecoration(
                    labelText: 'コスト（以下）',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'コストはメンバーだけが持つ',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(child: Text('指定なし')),
                    for (final c in _costOptions)
                      DropdownMenuItem<int?>(value: c, child: Text('$c 以下')),
                  ],
                  onChanged: store.setMaxCost,
                ),
                const SizedBox(height: 16),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('パラレルを表示'),
                // ★OFF は isParallel == false の刷りを「すべて」表示する
                //   （CLAUDE.md §5-(4)）。cardNumber ごとに 1 枚へ畳まない。
                subtitle: const Text('OFF で通常刷りだけを表示'),
                value: state.filter.showParallel,
                onChanged: store.setShowParallel,
              ),
              const Divider(height: 32),
              // ★件数が言えるのは `Ready` のときだけ（M3）。
              //   検索中や失敗時に 0 と書くと「0 件だった」と区別がつかない。
              Text(
                '${state.visibleCount ?? '—'} 件 / 全 ${state.totalCount} 件',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          );
        },
      );
}
