# Sucheme オンボーディングガイド

## システム要件

- Ruby 3.2 以上 (3.2.3 推奨)
- Bundler 2.x 以上

## セットアップ

### Linux / macOS

```bash
# リポジトリのクローン
git clone <repo-url>
cd sucheme-ruby

# Bundlerのインストール（未インストールの場合）
gem install bundler --user-install

# 依存関係のインストール（システムRubyを変更しない）
bundle config set --local path 'vendor/bundle'
bundle install

# 動作確認
bundle exec ruby bin/sucheme --version
echo '(+ 1 2)' | bundle exec ruby bin/sucheme
```

### Windows (PowerShell)

```powershell
# リポジトリのクローン
git clone <repo-url>
cd sucheme-ruby

# Bundlerのインストール（未インストールの場合）
gem install bundler --user-install

# 依存関係のインストール（システムRubyを変更しない）
bundle config set --local path 'vendor/bundle'
bundle install

# 動作確認
bundle exec ruby bin/sucheme --version
# Windowsではechoパイプが異なるため -e オプションを使用
bundle exec ruby bin/sucheme -e "(+ 1 2)"
```

> **Windowsでの注意点:**
> - シングルクォート `'` はPowerShellではダブルクォート `"` に置き換えてください
> - パスの区切り文字は `\` ですが、Rubyは `/` も受け付けます
> - ファイル実行: `bundle exec ruby bin/sucheme samples\01_basics\variables.scm`

## 基本的な使い方

### REPL (対話型)

```bash
bundle exec ruby bin/sucheme
```

```powershell
# Windows
bundle exec ruby bin/sucheme
```

### ファイルの実行

```bash
# Linux/macOS
bundle exec ruby bin/sucheme samples/01_basics/variables.scm

# Windows PowerShell
bundle exec ruby bin/sucheme samples\01_basics\variables.scm
```

### 式の評価

```bash
# Linux/macOS
bundle exec ruby bin/sucheme -e '(+ 1 2 3)'

# Windows PowerShell
bundle exec ruby bin/sucheme -e "(+ 1 2 3)"
```

### Webインターフェース

```bash
bundle exec ruby web/app.rb
# ブラウザで http://localhost:4567 を開く
```

## テストの実行

```bash
bundle exec rspec spec/ --format documentation
```

## ベンチマークの実行

```bash
bundle exec ruby benchmarks/benchmark.rb
```

## Scheme入門

詳しいチュートリアルは [`docs/TUTORIAL.md`](TUTORIAL.md) を参照してください。

```scheme
; コメント
(+ 1 2)                    ; => 3
(define x 10)              ; 変数定義
(define (square n) (* n n)); 関数定義
(lambda (x) x)             ; 無名関数（恒等関数）
(if #t "yes" "no")         ; 条件分岐
'(1 2 3)                   ; リスト
(car '(1 2 3))             ; => 1  先頭要素
(cdr '(1 2 3))             ; => (2 3)  残り
(map (lambda (x) (* x x)) '(1 2 3 4 5)) ; => (1 4 9 16 25)
```

## サンプルプログラム

`samples/` ディレクトリに100以上のサンプルプログラムがあります:

| カテゴリ | 説明 |
|---------|------|
| `01_basics/` | 変数、算術、条件分岐 |
| `02_data_structures/` | リスト、ベクタ、文字列 |
| `03_functions/` | ラムダ、クロージャ、高階関数 |
| `04_recursion/` | 再帰、末尾再帰 |
| `05_macros/` | define-syntax、syntax-rules |
| `06_io/` | 入出力、ファイル操作 |
| `07_advanced/` | 継続、遅延評価 |
| `08_practical/` | 実用プログラム |
| `09_continuations/` | call/cc |
| `10_exercises/` | 練習問題 |

## ディレクトリ構成

```
sucheme-ruby/
├── bin/sucheme          # 実行ファイル (CLI)
├── lib/sucheme/         # コアライブラリ
│   ├── lexer.rb         # 字句解析
│   ├── parser.rb        # 構文解析
│   ├── evaluator.rb     # 評価器 (TCO)
│   ├── environment.rb   # 環境管理
│   ├── primitives.rb    # 組み込み関数
│   ├── types.rb         # Scheme型定義
│   └── repl.rb          # REPL
├── spec/                # テスト (RSpec)
├── samples/             # サンプルプログラム
├── web/                 # Web UI (Sinatra)
├── docs/                # ドキュメント
│   ├── TUTORIAL.md      # 包括的チュートリアル
│   ├── ADR/             # アーキテクチャ決定記録
│   └── R5RS_COMPLIANCE.md  # R5RS対応状況
└── benchmarks/          # ベンチマーク
```

## トラブルシューティング

### `bundle: command not found`

```bash
# bundlerをユーザーインストール
gem install bundler --user-install

# パスを追加（シェルのプロファイルにも追記推奨）
export PATH="$(ruby -e 'puts Gem.user_dir')/bin:$PATH"
```

### Windows: `bundle` が見つからない

```powershell
# ユーザーGemパスを確認
ruby -e "puts Gem.user_dir"
# 出力例: C:/Users/yourname/.local/share/gem/ruby/3.2.0

# PATHに追加（PowerShell）
$env:PATH += ";$(ruby -e 'puts Gem.user_dir')\bin"
```

### `vendor/bundle` を使用する理由

システムの Ruby 環境を変更せずに開発できるようにするためです。
`bundle config set --local path 'vendor/bundle'` で設定された後は `bundle exec` で実行します。
