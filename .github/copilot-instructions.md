# GitHub Copilot 開発ガイド

## プロジェクトについて
このプロジェクトはRubyで実装されたR5RS準拠のSchemeインタープリタです。

## コーディング規約

### Ruby
- `frozen_string_literal: true` を全ファイルに付ける
- インデント: スペース2つ
- RuboCop準拠

### Scheme型
- `SchemeNull::INSTANCE` (`NULL`) - 空リスト
- `SchemePair` - ペア（cons cell）
- `SchemeSymbol` - シンボル（インターン済み）
- `SchemeChar` - 文字
- `SchemeVector` - ベクタ
- `SchemeProcedure` - クロージャ
- `SchemePrimitive` - 組み込み関数
- `SchemeMacro` - syntax-rulesマクロ
- `SchemeVoid::INSTANCE` (`VOID`) - 未指定値

### TCO（末尾呼び出し最適化）
`eval_expr`内のループで実装。末尾位置では`next`でループを継続。

### テスト
- RSpecを使用
- `spec/sucheme/` にテストを配置
- 新機能には必ずテストを追加

## よくある変更パターン

### プリミティブの追加
```ruby
prim(env, 'my-proc') do |arg1, arg2|
  # 処理
  result
end
```

### 特殊形式の追加
`evaluator.rb` の `eval_expr` メソッド内の `case head.name` に追加。

## 注意事項
- `SchemeNull`と`SchemeVoid`は直接インスタンス化しない。`NULL`/`VOID`定数を使用。
- `SchemeSymbol`は`SchemeSymbol.intern(name)`でインターン化。
- `eval_body`は末尾位置で`SchemeTailCall`を返す。
