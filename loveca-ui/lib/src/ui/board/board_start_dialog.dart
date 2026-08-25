/// 盤面の開始ダイアログ（決定 D79 / D81 / D88 / 盤面設計メモ §9 / §14）.
///
/// ★★ 決めるものを 6.2.1 の条文順に並べ、条番号を出す ★★
///
/// | 項目 | 条 |
/// |---|---|
/// | 相手デッキ | 6.2.1.1 |
/// | 先攻 | 6.2.1.4 ★**2 段**である |
/// | seed | 決定 D79（条文には無い。再現のための実装上の値） |
///
/// ★★ 6.2.1.4 の 2 段を 1 段に潰さない ★★
/// 条文は「**無作為にどちらかのプレイヤーを選択し**、そのプレイヤーが
/// **どちらが先攻プレイヤーとなるかを選びます**」の 2 段である。
/// ローカル対戦では形骸化するが、**UI が構造を潰すと Phase 6 で組み直しになる。**
/// → ①「選ぶ人」を決める（自分 / 相手 / 無作為）→ ②その人が先攻を選ぶ。
///
/// ★★ ただし 2 段を保つのはローカル対戦だけである（決定 D88 / D81 の訂正）★★
/// 条文は「**各プレイヤーは**無作為にどちらのプレイヤーを選択し」であり、
/// **プレイヤーが 1 人では手順そのものが成立しない。**ソロは常に自分が先攻。
/// ★**黙って飛ばさず理由を出す。**飛ばしたことが見えないと、
/// 「このアプリは 6.2.1.4 を実装していない」と読まれる。
///
/// ★★ ソロの相手デッキは**自分と同じもの**（決定 D81 の既定 / §14-5）★★
/// 空の `Deck` を採らない理由は 2 つ ——
/// (1) 6.2.1.5 で**手札 0 枚の `PlayerState`** という条文に存在しない状態を作る、
/// (2) 7.6.2 が空のメインデッキ + 空の控え室で 10.2.2 のリフレッシュを踏む経路が生まれる。
///
/// ★★ 6.1 を満たさないデッキでも開始できる。ただし黙って通さない ★★
/// アプリはサンドボックス（D-A）なので、条件を満たさないデッキで回すこと自体は正当。
/// **違反の中身を出して明示的に確認を取り**、盤面にも `BoardNotice` を残す。
///
/// ★★ 未知の刷りを含むデッキは開始できない ★★
/// `CardInstance` の `cardNumber` すら決められないため（`GameSetup` が投げる）。
/// **どの刷りが引けないかを出す**（決定 D35: 黙って消さない）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/board_mode.dart';
import '../../state/board_seed.dart';

/// 開始ダイアログの結果。★`GameSetup` にそのまま渡せる値だけを持つ。
class BoardStartRequest {
  const BoardStartRequest({
    required this.opponentDeck,
    required this.firstPlayerId,
    required this.seed,
  });

  final Deck opponentDeck;

  /// 6.2.1.4 の結果。★`GameSetup.begin` の引数になる。
  final String firstPlayerId;

  /// 決定 D79。★`SeededRng(seed)` を作る値。
  final int seed;
}

/// 盤面を始める側の playerId。★盤面の `viewerId` の既定にもなる（決定 D81）。
const String kSelfPlayerId = 'self';
const String kOpponentPlayerId = 'opponent';

Future<BoardStartRequest?> showBoardStartDialog(
  BuildContext context, {
  required Deck deck,
  required List<Deck> candidates,
  required BoardMode mode,
  required DeckValidationResult Function(Deck) validate,
}) =>
    showDialog<BoardStartRequest>(
      context: context,
      builder: (_) => _BoardStartDialog(
        deck: deck,
        candidates: candidates,
        mode: mode,
        validate: validate,
      ),
    );

class _BoardStartDialog extends StatefulWidget {
  const _BoardStartDialog({
    required this.deck,
    required this.candidates,
    required this.mode,
    required this.validate,
  });

  final Deck deck;
  final List<Deck> candidates;
  final BoardMode mode;
  final DeckValidationResult Function(Deck) validate;

  @override
  State<_BoardStartDialog> createState() => _BoardStartDialogState();
}

/// 6.2.1.4 の 1 段目「無作為にどちらかのプレイヤーを選択し」。
enum _Chooser { self, opponent, random }

class _BoardStartDialogState extends State<_BoardStartDialog> {
  late Deck _opponentDeck = widget.deck;
  late final TextEditingController _seed =
      TextEditingController(text: '${newBoardSeed()}');

  _Chooser _chooser = _Chooser.random;

  /// 1 段目の結果。★無作為を引いたらここに残し、**画面に出してから** 2 段目へ。
  String? _resolvedChooser;

  /// 2 段目「そのプレイヤーがどちらが先攻となるかを選びます」。
  String _firstPlayerId = kSelfPlayerId;

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  /// 6.2.1.4 の 1 段目を確定する。
  void _resolveChooser() {
    setState(() {
      _resolvedChooser = switch (_chooser) {
        _Chooser.self => kSelfPlayerId,
        _Chooser.opponent => kOpponentPlayerId,
        // ★ここが条文の「無作為に」。結果は値として残す（`board_seed.dart`）。
        _Chooser.random =>
          pickAtRandom(const [kSelfPlayerId, kOpponentPlayerId]),
      };
    });
  }

  int? get _parsedSeed => int.tryParse(_seed.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ★★ ソロの相手側は**自分と同じデッキ**（決定 D81 / §14-5）★★
    final versus = widget.mode == BoardMode.localVersus;
    final opponentDeck = versus ? _opponentDeck : widget.deck;

    final selfResult = widget.validate(widget.deck);
    final opponentResult = widget.validate(opponentDeck);

    // ★未知の刷りがあると GameSetup が投げる。ここで止める。
    //   ★ソロでは同じデッキなので selfResult と同じ答えになる。
    final blocked = selfResult.hasUnknownCards || opponentResult.hasUnknownCards;

    return AlertDialog(
      title: Text('${widget.mode.label}を始める'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- 6.2.1.1 ----
              _Step(
                ruleRef: '6.2.1.1',
                title: '使用するデッキ',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('自分: ${widget.deck.name}',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    // ★★ ソロでは相手を選ばせない。★黙って飛ばさず理由を出す ★★
                    if (!versus)
                      Text(
                        'ソロでは相手を置きません。'
                        '★1.1.1 が「原則 2 名」と定めているため盤面の内部では'
                        '相手側にも同じデッキを置きますが、'
                        '自分側の初期盤面（6.2.1.2 / 6.2.1.5）には影響しません。',
                        key: const ValueKey('solo-opponent-note'),
                        style: theme.textTheme.labelSmall,
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: const ValueKey('opponent-deck'),
                        initialValue: _opponentDeck.deckId,
                        decoration: const InputDecoration(
                          labelText: '相手',
                          helperText: '★同じデッキも選べます',
                          isDense: true,
                        ),
                        items: [
                          for (final candidate in widget.candidates)
                            DropdownMenuItem(
                              value: candidate.deckId,
                              child: Text(candidate.deckId == widget.deck.deckId
                                  ? '${candidate.name}（同じデッキ）'
                                  : candidate.name),
                            ),
                        ],
                        onChanged: (id) => setState(() {
                          _opponentDeck = widget.candidates
                              .firstWhere((d) => d.deckId == id);
                        }),
                      ),
                  ],
                ),
              ),

              // ---- 6.2.1.4（★2 段を保つのはローカル対戦だけ / 決定 D88）----
              if (!versus)
                _Step(
                  ruleRef: '6.2.1.4',
                  title: '先攻を決める',
                  // ★★ 条文は「各プレイヤーは無作為にどちらのプレイヤーを選択し」★★
                  //   プレイヤーが 1 人ではこの手順そのものが成立しない。
                  //   ★出さないだけでは「実装していない」と読まれる。理由を書く。
                  child: Text(
                    '★条文は「各プレイヤーは無作為にどちらのプレイヤーを選択し、'
                    'そのプレイヤーがどちらが先攻プレイヤーとなるかを選びます」ですが、'
                    'プレイヤーが 1 人ではこの手順が成立しません。'
                    'ソロでは常に自分が先攻です（8.4.13 の入れ替えも起きません）。',
                    key: const ValueKey('solo-first-player-note'),
                    style: theme.textTheme.labelSmall,
                  ),
                )
              else
              _Step(
                ruleRef: '6.2.1.4',
                title: '先攻を決める',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '★条文は 2 段です。「無作為にどちらかのプレイヤーを選択し、'
                      'そのプレイヤーがどちらが先攻となるかを選びます」',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Text('① 選ぶ人を決める', style: theme.textTheme.labelMedium),
                    SegmentedButton<_Chooser>(
                      segments: const [
                        ButtonSegment(value: _Chooser.random, label: Text('無作為')),
                        ButtonSegment(value: _Chooser.self, label: Text('自分')),
                        ButtonSegment(
                            value: _Chooser.opponent, label: Text('相手')),
                      ],
                      selected: {_chooser},
                      onSelectionChanged: (v) => setState(() {
                        _chooser = v.first;
                        _resolvedChooser = null;
                      }),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        OutlinedButton(
                          key: const ValueKey('resolve-chooser'),
                          onPressed: _resolveChooser,
                          child: const Text('①を決定'),
                        ),
                        const SizedBox(width: 8),
                        if (_resolvedChooser != null)
                          Text(
                            '選ばれたのは: '
                            '${_resolvedChooser == kSelfPlayerId ? '自分' : '相手'}',
                            key: const ValueKey('resolved-chooser'),
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('② その人が先攻を選ぶ', style: theme.textTheme.labelMedium),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: kSelfPlayerId, label: Text('自分が先攻')),
                        ButtonSegment(
                            value: kOpponentPlayerId, label: Text('相手が先攻')),
                      ],
                      selected: {_firstPlayerId},
                      onSelectionChanged: (v) =>
                          setState(() => _firstPlayerId = v.first),
                    ),
                  ],
                ),
              ),

              // ---- seed（決定 D79）----
              _Step(
                ruleRef: 'D79',
                title: 'seed（条文には無い / 再現のための値）',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('seed-field'),
                        controller: _seed,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'seed',
                          helperText: '★同じ seed を入れると同じ初期盤面になります',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '新しい seed',
                      onPressed: () =>
                          setState(() => _seed.text = '${newBoardSeed()}'),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),

              // ---- 検証（6.1）----
              _Validation(
                label: '自分',
                deck: widget.deck,
                result: selfResult,
              ),
              // ★ソロで「相手のデッキが 6.1 を満たさない」は幽霊である（§14-5）。
              if (versus)
                _Validation(
                  label: '相手',
                  deck: _opponentDeck,
                  result: opponentResult,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const ValueKey('start-board'),
          // ★未知の刷りがあると盤面に置けないので押させない。
          //   ★6.1 の枚数違反では止めない（サンドボックス / D-A）。
          onPressed: blocked || _parsedSeed == null
              ? null
              : () => Navigator.of(context).pop(BoardStartRequest(
                    opponentDeck: opponentDeck,
                    // ★ソロは常に自分が先攻（決定 D88）。
                    firstPlayerId: versus ? _firstPlayerId : kSelfPlayerId,
                    seed: _parsedSeed!,
                  )),
          child: const Text('始める'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.ruleRef,
    required this.title,
    required this.child,
  });

  final String ruleRef;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ★条番号を画面に出す（根拠が追えるように）。
                Text(ruleRef,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
}

/// 6.1 の検証結果。★「満たしている」も出す（黙って通したと区別する）。
class _Validation extends StatelessWidget {
  const _Validation({
    required this.label,
    required this.deck,
    required this.result,
  });

  final String label;
  final Deck deck;
  final DeckValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.hasUnknownCards) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '$label（${deck.name}）: カードデータが未取得の刷りがあるため始められません — '
          '${result.unknownPrintingIds.join(', ')}',
          key: ValueKey('unknown-$label'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }

    if (result.isValid) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label（${deck.name}）: 6.1 を満たしています',
            style: theme.textTheme.bodySmall),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label（${deck.name}）: 6.1 を満たしていませんが、このまま回せます — '
        '${result.issues.map((i) => i.message).join(' / ')}',
        key: ValueKey('invalid-$label'),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.tertiary),
      ),
    );
  }
}
