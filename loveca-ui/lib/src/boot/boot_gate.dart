/// R1 起動ゲートの表示（`docs/UI設計メモ.md` §2-2 / §3-5）.
///
/// ★★ どの段で失敗したかを必ず出す ★★
/// 4 段を明示的に順に実行しているのは、失敗の原因を段で切り分けるためである。
/// 「エラーが出た」だけでは、続行できる状態か否かを利用者が判断できない。
library;

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import 'boot_controller.dart';
import 'boot_steps.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key, required this.steps, required this.builder});

  final BootSteps steps;

  /// 起動が通ったあとに出す画面。
  final WidgetBuilder builder;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final BootController _controller = BootController(widget.steps);

  @override
  void initState() {
    super.initState();
    _controller.run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BootState>(
        valueListenable: _controller,
        builder: (context, state, _) => switch (state) {
          BootRunning(:final stage) => _BootProgress(stage: stage),
          BootFailed() => _BootFailure(state: state),
          BootReady() => AppScope(
              environment: state.environment,
              notices: state.notices,
              timings: state.timings,
              child: Builder(builder: widget.builder),
            ),
        },
      );
}

class _BootProgress extends StatelessWidget {
  const _BootProgress({required this.stage});

  final BootStageId stage;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(stage.label, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              // ★通った段が見えるようにする。止まった位置が分かる。
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in BootStageId.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        s.index < stage.index
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 14,
                        color: s.index < stage.index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.state});

  final BootFailed state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    // ★どの段で失敗したかが見出しになる。
                    Expanded(
                      child: Text(
                        '起動できませんでした — ${state.stage.label}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  '${state.error}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (state.searchedPaths.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  // ★★ どこを見て無かったのかを出す（決定 D60）★★
                  // 3 段の解決順を持つ以上、これが出ないと利用者は直せない。
                  Text('探した場所', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  for (final path in state.searchedPaths)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText(
                        '・$path',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SelectableText(
                    '環境変数 LOVECA_DIST_DIR で場所を指定できます。',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
