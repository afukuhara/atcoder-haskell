# Haskell + Cabal: cargo-compete-like AtCoder environment

`online-judge-tools` + Cabal を `bin/hc` でまとめた、
Haskell 用の軽量な `cargo-compete` 風環境です。

## Directory layout

```text
haskell-atcoder/
├── atcoder-hs.cabal
├── cabal.project
├── cabal.project.atcoder
├── Makefile
├── bin/
│   └── hc
├── templates/
│   └── Main.hs
├── tests/
│   └── hc_new_test.sh       # bin/hc のスタブテスト (make check)
├── .build/                  # hc が選択中の Main.hs をコピーする場所
└── contests/
    └── abc473/
        ├── abc473_a/
        │   ├── Main.hs
        │   └── test/
        ├── abc473_b/
        │   ├── Main.hs
        │   └── test/
        └── ...
```

Cabal の package はルートに **1つだけ**です。
`hc test a` などを実行すると、対象問題の `Main.hs` が `.build/Main.hs`
へコピーされ、通常の `cabal build` でコンパイルされます。

これにより、問題ごとに `.cabal` を複製せず、依存パッケージと
GHC オプションを一元管理できます。

## 1. Prerequisites

必要なもの:

- GHC / Cabal
- Python 3
- `online-judge-tools` (`oj`, `oj-api`)

AtCoder とローカル環境をできるだけ一致させるなら GHC 9.8.4 を推奨します。

例:

```bash
ghcup install ghc 9.8.4
ghcup set ghc 9.8.4

python3 -m pip install --user online-judge-tools
```

環境によっては `pipx` や `uv tool` を使ってインストールしても構いません。

## 2. PATH

リポジトリのルートで:

```bash
export PATH="$(pwd)/bin:$PATH"
```

恒久化する場合は、絶対パスにして `~/.zshrc` などへ追加してください。

```bash
export PATH="$HOME/path/to/haskell-atcoder/bin:$PATH"
```

## 3. Initial setup

```bash
hc doctor
hc setup
hc login
```

`hc setup` は `templates/Main.hs` を使った Cabal の初回 build を行います。

## 4. Create a contest

```bash
hc new abc473
```

内部では次を行います。

1. `oj-api get-contest` で問題一覧を取得 (1 リクエスト)
2. 各問題に `templates/Main.hs` をコピー
3. 各問題で `oj download` を実行してサンプルを取得

生成結果:

```text
contests/abc473/
├── abc473_a/
│   ├── Main.hs
│   └── test/
├── abc473_b/
│   ├── Main.hs
│   └── test/
└── ...
```

既存の `Main.hs` とサンプルは上書きしません。途中で失敗した場合は
`hc new abc473` を再実行すると、欠けている問題だけを取得し直します。

### 429 Too Many Requests について

AtCoder は短時間に連続したリクエストへ `429 Too Many Requests` を返します。
以前使っていた `oj-prepare` は 1 問につき 3 回、間隔を空けずにアクセスするため、
問題数が多いと途中で 429 になっていました
(入力フォーマット解析の `AssertionError` なども出ますが、
`templates/Main.hs` は静的テンプレートなので解析結果は使っていません)。

`hc new` は 1 問につき `oj download` を 1 回だけ実行し、
リクエストの間隔を空け、失敗したときはリトライします。
間隔は環境変数で調整できます。

| 変数 | 既定値 | 意味 |
|------|--------|------|
| `HC_REQUEST_INTERVAL` | `2` | 各ダウンロード前に待つ秒数 |
| `HC_DOWNLOAD_ATTEMPTS` | `3` | 1 問あたりの最大試行回数 |
| `HC_RETRY_WAIT` | `10` | リトライ前に待つ秒数 |

## 5. Solve / test / submit

コンテストディレクトリへ移動:

```bash
cd contests/abc473
```

A問題を編集:

```bash
$EDITOR abc473_a/Main.hs
```

テスト:

```bash
hc test a
```

提出:

```bash
hc submit a
```

`hc submit a` は **ローカルテストに成功してから提出**します。

テストを省略して提出したい場合:

```bash
hc submit-only a
```

## Command correspondence

```text
cargo compete new abc473     -> hc new abc473
cargo compete test a         -> hc test a
cargo compete submit a       -> hc submit a
cargo compete test --release -> 常に Cabal -O2 で build
```

## Task specification

### コンテストディレクトリから

```bash
cd contests/abc473

hc build a
hc run a
hc test a
hc submit a
hc open a
```

### 問題ディレクトリから

```bash
cd contests/abc473/abc473_a

hc test
hc submit
```

### リポジトリルートなどから

```bash
hc test abc473_a
hc test abc473 a

hc submit abc473_a
hc submit abc473 a
```

## Makefile

ルートから実行する場合のショートカットです。

```bash
make new CONTEST=abc473
make test CONTEST=abc473 TASK=a
make run CONTEST=abc473 TASK=a
make submit CONTEST=abc473 TASK=a
```

## Input template

`templates/Main.hs` は `attoparsec` ベースです。

最初から以下の parser helper が入っています。

```haskell
int :: Parser Int
integer :: Parser Integer
word :: Parser BS.ByteString
ints :: Int -> Parser [Int]
```

問題に合わせて主にここを書き換えます。

```haskell
data Input = ...

input :: Parser Input
input = ...

solve :: Input -> IO ()
solve = ...
```

`parseOnly` が `Left` になった場合はローカル実行時にエラーにしているため、
入力 parser の書き間違いにも気づきやすくしています。

## Cabal dependencies

`atcoder-hs.cabal` には、競プロでよく使う以下を入れています。

- `attoparsec`
- `bytestring`
- `containers`
- `vector`
- `unordered-containers`
- `primitive`
- `mtl`
- `extra`
- `ac-library-hs`

不要なものは削って構いません。

## Match AtCoder package versions

通常は:

```bash
cabal build
```

で十分です。

AtCoder の主要パッケージバージョンに寄せたい場合は:

```bash
cabal --project-file=cabal.project.atcoder build
```

を使えます。

GHC 自体も AtCoder と合わせる場合は GHC 9.8.4 を使用してください。

## Useful commands

```bash
hc doctor
hc list
hc list abc473
hc clean
hc open abc473 a
```

`bin/hc` 自身のテスト(ネットワーク不要のスタブテスト):

```bash
make check
```

`hc doctor` はローカル GHC が 9.8.4 と異なる場合も表示します。

## macOS のリンクエラー (tapi error: malformed file)

`hc build` / `hc test` が次のエラーで失敗する場合:

```
ld: tapi error: malformed file
.../MacOSX27.0.sdk/System/Library/Frameworks/Security.framework/.../Security.tbd:4:20: error: unknown architecture
                   arm64e.x1-macos, arm64e.x1-maccatalyst ]
```

原因は GHC/Cabal ではなく Command Line Tools の構成です。`xcrun` は
インストール済みで最も新しい SDK を選ぶため、OS より新しい SDK
(例: macOS 26 上の `MacOSX27.0.sdk`) が選ばれます。その SDK の `.tbd` は
新しい `arm64e.x1` ターゲットを含み、古い `ld` は解析できません
(`clang hello.c` のような素の C のリンクも同様に失敗します)。

`bin/hc` はビルド前に `SDKROOT` を OS のメジャーバージョンに一致する
最新 SDK へ固定してこれを回避します。現在選ばれている SDK は
`hc doctor` で確認できます。

恒久的に直す場合は次のどちらかです:

- Command Line Tools を SDK に合うバージョンへ更新する
  (`softwareupdate --list` / Apple Developer からの再インストール)
- 使っていない新しい SDK を削除する
  (`sudo rm -rf /Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk`)

シェル側で固定する場合は `export SDKROOT="$(xcrun --sdk macosx26.5 --show-sdk-path)"`
のように設定します。
