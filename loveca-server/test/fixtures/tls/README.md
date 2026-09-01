# ★★ 試験専用の証明書（決定 **D131-7**）★★

★★**本番で使ってはならない。★秘密鍵がこのリポジトリに在る。**★★

| 何 | 中身 |
|---|---|
| `localhost-TEST-ONLY.cert.pem` | ★自己署名の証明書（`CN=localhost` / `subjectAltName` に `localhost` と `127.0.0.1`） |
| `localhost-TEST-ONLY.key.pem` | ★★**その秘密鍵。★公開されている**★★ |

## ★★ なぜ置いてあるか ★★

★**待ち受け（`serveAuth`）を★★本当に張って確かめたい★★**（**D-10** —— ★張らずに書くと
「★待ち受けの配線が正しいか」を 1 つも見ていない）。
★`SecurityContext` は★**証明書と鍵をファイルからしか読めない**ので、★試験にもファイルが要る。

★★**作るたびに生成しない**★★ —— ★`openssl` が無い機械で★★飛ばす検査（skip）ができる★★。
`CLAUDE.md` §3 は「★skip 件数も併記すること」と定めており、
★★**飛ばした検査は「検証しているつもりで検証していない」状態になる。**★★

## ★★ 柵（決定 **D131-7**）★★

★★**`lib` から 1 度も参照されないこと。**★★
★**参照されたら★★本番で使われうる★★。**
★**走査で見張る**（`test/tls_fixture_test.dart`）。

## ★ 作り直すとき

```
openssl req -x509 -newkey rsa:2048 \
  -keyout localhost-TEST-ONLY.key.pem \
  -out localhost-TEST-ONLY.cert.pem \
  -days 36500 -nodes -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

★**期限は 100 年にしてある**（★★期限切れで★ある日突然★検査が落ちるのを避ける★★）。
