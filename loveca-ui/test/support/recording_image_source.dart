/// どの imageHash で画像が要求されたかを記録するフェイク（M-B1 / 決定 D77）.
///
/// ★★ 「画面に出ない」を文字列で見ても証明にならない ★★
/// 盤面は絵を描くので、`find.text(printingId)` が 0 件でも
/// **絵として出ている**可能性が残る。**要求そのものが来ないこと**を見る。
///
/// ★★ この検査は「生きていること」を対で見なければならない（D-10）★★
/// `provider` が常に null を返す実装でも「来ない」は通ってしまう。
/// **同じカードを手札に置いたときには来ること**を必ず対で固定する
/// （`test/board/board_secrecy_test.dart`）。
library;

import 'package:flutter/widgets.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';

class RecordingImageSource implements CardImageSource {
  RecordingImageSource({this.hasImageStore = true});

  /// ★決定 D89。既定は「置き場はある」（この fake が見たいのは要求の有無）。
  @override
  final bool hasImageStore;

  /// `provider` が呼ばれた imageHash（重複あり。呼ばれた回数が分かる）。
  final List<String> requested = [];

  /// 呼ばれたときの `cacheWidthPx`（D42 の検算に使う）。
  final List<int> cacheWidths = [];

  @override
  ImageProvider? provider(
    String imageHash,
    CardImageSize size, {
    required int cacheWidthPx,
  }) {
    if (imageHash.isEmpty) return null;
    requested.add(imageHash);
    cacheWidths.add(cacheWidthPx);
    // ★実ファイルを読ませない。要求が来たことだけを記録する。
    //   ★null を返すと `CardThumb` がプレースホルダのままになるが、
    //   この fake が見たいのは「要求が来たか」であって描画結果ではない。
    return null;
  }
}
