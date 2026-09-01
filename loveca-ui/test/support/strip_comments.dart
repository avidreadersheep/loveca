/// ★★ 行コメントと doc を落とす（★★D-30 の受け★★ / ★2 つの走査が使う）★★
///
/// ★★ なぜ要るか ★★
/// ★**禁止対象を説明した doc は★★禁止対象と同じ字面を必ず含む★★**（**D-30**）。
/// → ★**素の走査では★★説明そのものが当たる★★**（★2 か所で実際に当たった）。
/// ★★**除外の一覧を持たない**★★ —— ★**除外を足すと★★その除外自身が穴になる★★。**
///
/// ★★ このファイルには★逆斜線を 1 つも書かない（**D-38**）★★
/// ★**道具の経路で★★2 つ続けた逆斜線が 1 つに畳まれる★★**（★実測 / ★4 回踏んだ）。
library;

String stripComments(String source) {
  final out = StringBuffer();
  var inString = false;
  String? quote;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (inString) {
      out.write(c);
      if (c == quote) inString = false;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      quote = c;
      out.write(c);
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != String.fromCharCode(10)) {
        i++;
      }
      out.write(String.fromCharCode(10));
      continue;
    }
    out.write(c);
  }
  return out.toString();
}
