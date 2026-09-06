# Haskell + Cabal: cargo-compete-like AtCoder environment

`oj-prepare` + `online-judge-tools` + Cabal を `bin/hc` でまとめた、
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
├── config/
│   └── prepare.config.toml
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
- `online-judge-tools` (`oj`)
- `online-judge-template-generator` (`oj-prepare`)

AtCoder とローカル環境をできるだけ一致させるなら GHC 9.8.4 を推奨します。

例:

```bash
ghcup install ghc 9.8.4
ghcup set ghc 9.8.4

python3 -m pip install --user online-judge-tools online-judge-template-generator
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

`hc setup` は:

1. `templates/Main.hs` を `oj-prepare` 用テンプレートとして登録
2. Cabal の初回 build

を行います。

## 4. Create a contest

```bash
hc new abc473
```

内部では概ね次を実行します。

```bash
oj-prepare   --config-file config/prepare.config.toml   https://atcoder.jp/contests/abc473
```

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

### oj-prepare の解析エラーについて

`oj-prepare` は入力フォーマットの解析に失敗した問題があると、
最後に `AssertionError` などのトレースバックを出して非ゼロ終了します
(例: `abc465_g`。同じ添字名を使う入れ子ループがあると
`onlinejudge_template/analyzer/match.py` の `assert` に引っかかります)。

この解析結果は `templates/Main.hs` が静的テンプレートであるため使われず、
`Main.hs` の生成とサンプルのダウンロードは解析失敗後も実行されます。

そのため `hc new` は `oj-prepare` の終了ステータスではなく、
**生成されたファイル**で成否を判定します。

- `Main.hs` が無い問題 -> `templates/Main.hs` をコピー
- サンプルが無い問題 -> `oj download` で取得し直す
- それでも欠けている問題があるときだけ `hc new` は失敗する

トレースバックが出ていても最後に

```text
==> ready: .../contests/abc465 (7 problems)
```

と表示されていれば、全問題が揃っています。

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
