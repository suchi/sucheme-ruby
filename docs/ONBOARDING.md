# Sucheme オンボーディングガイド

## セットアップ

```bash
# リポジトリのクローン
git clone <repo-url>
cd sucheme-ruby

# 依存関係のインストール
export PATH="$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH"
bundle install --path vendor/bundle

# 動作確認
bundle exec ruby bin/sucheme --version
echo '(+ 1 2)' | bundle exec ruby bin/sucheme
```

## 基本的な使い方

### REPL
```bash
bundle exec ruby bin/sucheme
```

### ファイルの実行
```bash
bundle exec ruby bin/sucheme samples/01_basics/variables.scm
```

### 式の評価
```bash
bundle exec ruby bin/sucheme -e '(+ 1 2 3)'
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

## Scheme入門

```scheme
; コメント
(+ 1 2)           ; => 3
(define x 10)     ; 変数定義
(lambda (x) x)    ; 恒等関数
(if #t "yes" "no") ; 条件分岐
'(1 2 3)          ; リスト
```

## ディレクトリ構成

```
sucheme-ruby/
├── bin/sucheme      # 実行ファイル
├── lib/sucheme/     # コアライブラリ
├── spec/            # テスト
├── samples/         # サンプルプログラム
├── web/             # Web UI
├── docs/            # ドキュメント
└── benchmarks/      # ベンチマーク
```
