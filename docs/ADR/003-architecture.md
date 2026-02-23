# ADR 003: アーキテクチャ決定

## ステータス
採用

## コンテキスト
インタープリタのアーキテクチャを決定する必要があります。

## 決定事項

### 1. トランポリニングによるTCO
末尾呼び出し最適化には、ループ+`SchemeTailCall`オブジェクトを使用します。

```ruby
def eval_expr(expr, env)
  loop do
    # 末尾位置ではSchemeTailCallを返す代わりに
    # exprとenvを更新してループを継続
    expr = next_expr
    env = next_env
    next
  end
end
```

### 2. 環境チェーン
レキシカルスコープを親チェーンで実装します。

### 3. シングルトンのNULLとVOID
`SchemeNull`と`SchemeVoid`はシングルトンパターンで実装。

### 4. syntax-rulesマクロ
パターンマッチングとテンプレート展開を純Rubyで実装。

### 5. call/ccはthrow/catchで実装
Ruby組み込みの`throw`/`catch`を使用して継続を実現（脱出継続限定）。

## トレードオフ
- 完全な継続はFiberを使用すれば可能だが複雑度が増す
- 現実装は脱出継続のみサポート
