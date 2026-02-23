# Sucheme Schemeチュートリアル

このチュートリアルでは、sucheme-ruby で実装された Scheme のすべての主要機能を、実行可能なサンプルコードから学べるようになっています。

## 目次

1. [基礎 - 式と値](#1-基礎---式と値)
2. [算術演算](#2-算術演算)
3. [変数とdefine](#3-変数とdefine)
4. [条件分岐](#4-条件分岐)
5. [関数（lambda）](#5-関数lambda)
6. [リスト操作](#6-リスト操作)
7. [再帰](#7-再帰)
8. [末尾再帰とTCO](#8-末尾再帰とtco)
9. [高階関数](#9-高階関数)
10. [クロージャ](#10-クロージャ)
11. [let, let*, letrec](#11-let-let-letrec)
12. [文字列操作](#12-文字列操作)
13. [文字操作](#13-文字操作)
14. [ベクタ](#14-ベクタ)
15. [入出力](#15-入出力)
16. [do ループ](#16-do-ループ)
17. [マクロ - define-syntax](#17-マクロ---define-syntax)
18. [quasiquote](#18-quasiquote)
19. [継続 - call/cc](#19-継続---callcc)
20. [遅延評価 - delay/force](#20-遅延評価---delayforce)
21. [多値 - values](#21-多値---values)
22. [数値の詳細](#22-数値の詳細)
23. [等価述語](#23-等価述語)
24. [テール位置と最適化](#24-テール位置と最適化)
25. [実用例 - データ処理](#25-実用例---データ処理)
26. [実用例 - アルゴリズム](#26-実用例---アルゴリズム)

---

## 1. 基礎 - 式と値

Scheme の式は S 式（S-expression）で書きます。`(演算子 引数...)` の形式です。

```scheme
; これはコメント

; 数値リテラル
42          ; 整数
3.14        ; 浮動小数点数
1/3         ; 有理数
-7          ; 負の整数

; 文字列リテラル
"hello"     ; 文字列
"改行\nあり"  ; エスケープシーケンス

; 真偽値
#t          ; true
#f          ; false

; 文字リテラル
#\a         ; 文字 'a'
#\space     ; スペース文字
#\newline   ; 改行文字

; シンボル
'hello      ; シンボル hello （クォートで評価を止める）
```

サンプルファイル: `samples/01_basics/literals.scm`

---

## 2. 算術演算

```scheme
; 基本演算（可変個引数）
(+ 1 2 3 4 5)   ; => 15
(* 2 3 4)        ; => 24
(- 10 3 2)       ; => 5
(/ 120 4 3)      ; => 10

; 単項マイナス
(- 5)            ; => -5

; 整数除算
(quotient 17 5)  ; => 3
(remainder 17 5) ; => 2
(modulo -7 3)    ; => 2   (常に非負)

; 比較
(< 1 2 3 4)      ; => #t  (全て昇順)
(<= 1 1 2)       ; => #t
(= 3 3 3)        ; => #t
(> 5 3 1)        ; => #t

; 数学関数
(abs -5)         ; => 5
(max 1 3 2)      ; => 3
(min 1 3 2)      ; => 1
(expt 2 10)      ; => 1024
(sqrt 16)        ; => 4
(floor 3.7)      ; => 3.0
(ceiling 3.2)    ; => 4.0
(round 3.5)      ; => 4.0
(truncate -3.7)  ; => -3.0

; 変換
(exact->inexact 1/3)  ; => 0.3333...
(inexact->exact 0.5)  ; => 1/2
(number->string 255 16)  ; => "ff"  (16進数)
(string->number "ff" 16) ; => 255
```

サンプルファイル: `samples/01_basics/arithmetic.scm`

---

## 3. 変数とdefine

```scheme
; 変数定義
(define x 10)
(define y 20)
(define z (+ x y))   ; => 30

; 関数定義（省略記法）
(define (square n)
  (* n n))

(square 5)   ; => 25

; 関数定義（lambda形式）
(define cube
  (lambda (n)
    (* n n n)))

(cube 3)     ; => 27

; set! で変数を変更
(define counter 0)
(set! counter (+ counter 1))
counter      ; => 1

; 複数の式を持つ関数（begin）
(define (show-and-square n)
  (display "n = ")
  (display n)
  (newline)
  (* n n))

(show-and-square 7)  ; 表示して 49 を返す
```

サンプルファイル: `samples/01_basics/variables.scm`

---

## 4. 条件分岐

```scheme
; if
(if (> 5 3)
    "yes"
    "no")     ; => "yes"

; if（else省略 - 偽の場合はvoid）
(if #f
    (display "never"))  ; 何も表示しない

; cond
(define (classify n)
  (cond ((< n 0) "negative")
        ((= n 0) "zero")
        ((< n 10) "small")
        (else "large")))

(classify -5)   ; => "negative"
(classify 0)    ; => "zero"
(classify 7)    ; => "small"
(classify 100)  ; => "large"

; cond の => 記法
(cond ((assv 2 '((1 . "one") (2 . "two") (3 . "three")))
       => cdr)
      (else "not found"))  ; => "two"

; case
(define (day-type day)
  (case day
    ((mon tue wed thu fri) "weekday")
    ((sat sun) "weekend")
    (else "unknown")))

(day-type 'mon)  ; => "weekday"
(day-type 'sat)  ; => "weekend"

; and / or
(and #t #t #t)        ; => #t
(and 1 2 3)           ; => 3   (最後の値)
(and 1 #f 3)          ; => #f
(or #f #f 42)         ; => 42  (最初の真の値)
(or #f #f #f)         ; => #f

; when / unless
(when (> 5 3)
  (display "5 > 3")
  (newline))

(unless (= 1 2)
  (display "1 != 2")
  (newline))

; not
(not #f)    ; => #t
(not 42)    ; => #f  (0も含め、#f以外は全て真)
```

サンプルファイル: `samples/01_basics/conditionals.scm`

---

## 5. 関数（lambda）

```scheme
; 基本的なlambda
(define add (lambda (x y) (+ x y)))
(add 3 4)    ; => 7

; 可変個引数
(define (sum . args)
  (apply + args))
(sum 1 2 3 4 5)  ; => 15

; 残余引数
(define (first-and-rest first . rest)
  (list first rest))
(first-and-rest 1 2 3 4)  ; => (1 (2 3 4))

; 即時実行ラムダ
((lambda (x y) (* x y)) 6 7)  ; => 42

; 関数を返す関数
(define (make-adder n)
  (lambda (x) (+ x n)))

(define add5 (make-adder 5))
(define add10 (make-adder 10))

(add5 3)    ; => 8
(add10 3)   ; => 13

; 引数なし関数
(define (get-pi) 3.14159)
(get-pi)    ; => 3.14159

; 複数返り値（begin）
(define (swap! pair)
  (let ((tmp (car pair)))
    (set-car! pair (cdr pair))
    (set-cdr! pair tmp)
    pair))
```

サンプルファイル: `samples/03_functions/lambda.scm`

---

## 6. リスト操作

```scheme
; リストの構築
'(1 2 3)                  ; クォートリスト
(list 1 2 3)              ; list 関数
(cons 1 '(2 3))           ; => (1 2 3)
(cons 1 (cons 2 (cons 3 '()))) ; => (1 2 3)

; 基本アクセス
(car '(1 2 3))    ; => 1
(cdr '(1 2 3))    ; => (2 3)
(cadr '(1 2 3))   ; => 2  (= (car (cdr ...)))
(caddr '(1 2 3))  ; => 3
(cadddr '(1 2 3 4)) ; => 4

; 述語
(null? '())      ; => #t
(null? '(1))     ; => #f
(pair? '(1 2))   ; => #t
(pair? '())      ; => #f
(list? '(1 2 3)) ; => #t

; リスト操作
(length '(1 2 3))          ; => 3
(append '(1 2) '(3 4) '(5)) ; => (1 2 3 4 5)
(reverse '(1 2 3))          ; => (3 2 1)
(list-tail '(a b c d) 2)    ; => (c d)
(list-ref '(a b c d) 2)     ; => c

; 探索
(member 3 '(1 2 3 4))       ; => (3 4)
(member 5 '(1 2 3 4))       ; => #f
(memv 'b '(a b c))          ; => (b c) （eqv?で比較）
(assoc "b" '(("a" 1) ("b" 2) ("c" 3)))  ; => ("b" 2)
(assv 2 '((1 "one") (2 "two") (3 "three"))) ; => (2 "two")

; ドット対（improper list）
(cons 1 2)        ; => (1 . 2)
(car (cons 1 2))  ; => 1
(cdr (cons 1 2))  ; => 2

; リスト変換
(map (lambda (x) (* x x)) '(1 2 3 4 5))  ; => (1 4 9 16 25)
(filter odd? '(1 2 3 4 5 6))              ; => (1 3 5)
(for-each display '(1 2 3))  ; 1 2 3 を表示（戻り値はvoid）
```

サンプルファイル: `samples/02_data_structures/lists.scm`

---

## 7. 再帰

```scheme
; 基本的な再帰（フィボナッチ）
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(fib 10)  ; => 55

; リストを再帰で処理
(define (my-length lst)
  (if (null? lst)
      0
      (+ 1 (my-length (cdr lst)))))

(my-length '(a b c d))  ; => 4

; 再帰でリストを構築
(define (iota n)
  (define (helper i)
    (if (= i n)
        '()
        (cons i (helper (+ i 1)))))
  (helper 0))

(iota 5)  ; => (0 1 2 3 4)

; 相互再帰
(define (my-even? n)
  (if (= n 0) #t (my-odd? (- n 1))))

(define (my-odd? n)
  (if (= n 0) #f (my-even? (- n 1))))

(my-even? 10)  ; => #t
(my-odd? 7)    ; => #t

; 竹内関数（Takeuchi function）
(define (tak x y z)
  (if (not (< y x))
      z
      (tak (tak (- x 1) y z)
           (tak (- y 1) z x)
           (tak (- z 1) x y))))

(tak 7 4 2)   ; => 7（少し時間がかかる）
```

サンプルファイル: `samples/04_recursion/basic_recursion.scm`

---

## 8. 末尾再帰とTCO

末尾再帰（tail recursion）とは、関数の最後の操作が再帰呼び出しになっている形式です。
sucheme はTCO（末尾呼び出し最適化）を実装しているので、末尾再帰はスタックオーバーフローになりません。

```scheme
; 末尾再帰でのフィボナッチ（効率的）
(define (fib-tail n a b)
  (cond ((= n 0) a)
        ((= n 1) b)
        (else (fib-tail (- n 1) b (+ a b)))))

(define (fib n) (fib-tail n 0 1))
(fib 100)  ; 大きな数でもスタックオーバーフローしない

; 末尾再帰で合計
(define (sum-list lst acc)
  (if (null? lst)
      acc
      (sum-list (cdr lst) (+ acc (car lst)))))

(sum-list '(1 2 3 4 5) 0)  ; => 15

; 100万回の反復もOK
(define (count-down n)
  (if (= n 0)
      'done
      (count-down (- n 1))))

(count-down 1000000)  ; => done

; named let で繰り返し
(let loop ((i 0) (acc 0))
  (if (= i 10)
      acc
      (loop (+ i 1) (+ acc i))))  ; => 45
```

サンプルファイル: `samples/04_recursion/tail_recursion.scm`

---

## 9. 高階関数

```scheme
; map: リストの各要素に関数を適用
(map (lambda (x) (* x 2)) '(1 2 3 4 5))
; => (2 4 6 8 10)

; filter: 条件を満たす要素だけ残す
(filter even? '(1 2 3 4 5 6 7 8))
; => (2 4 6 8)

; for-each: 副作用のための繰り返し
(for-each
  (lambda (x) (display x) (display " "))
  '(1 2 3 4 5))
; 表示: 1 2 3 4 5

; apply: リストを引数として関数を呼ぶ
(apply + '(1 2 3 4 5))     ; => 15
(apply max '(3 1 4 1 5 9)) ; => 9
(apply string-append '("hello" " " "world")) ; => "hello world"

; 高階関数の組み合わせ
(apply + (map (lambda (x) (* x x)) '(1 2 3 4 5)))
; => 55  (1^2 + 2^2 + 3^2 + 4^2 + 5^2)

; 関数を返す（カリー化）
(define (curry f)
  (lambda (x) (lambda (y) (f x y))))

(define add (curry +))
((add 3) 4)    ; => 7

; compose: 関数の合成
(define (compose f g)
  (lambda (x) (f (g x))))

(define inc (lambda (x) (+ x 1)))
(define double (lambda (x) (* x 2)))
(define inc-then-double (compose double inc))
(inc-then-double 5)  ; => 12  (* 2 (+ 5 1))

; fold (畳み込み)
(fold-right + 0 '(1 2 3 4 5))  ; => 15
(fold-left  + 0 '(1 2 3 4 5))  ; => 15
(fold-right cons '() '(1 2 3))  ; => (1 2 3)
(fold-left (lambda (acc x) (cons x acc)) '() '(1 2 3))  ; => (3 2 1)

; reduce
(reduce + 0 '(1 2 3 4 5))  ; => 15
```

サンプルファイル: `samples/03_functions/higher_order.scm`

---

## 10. クロージャ

クロージャは関数が定義された環境（スコープ）を閉じ込めます。

```scheme
; カウンタの例
(define (make-counter)
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      count)))

(define c1 (make-counter))
(define c2 (make-counter))

(c1)  ; => 1
(c1)  ; => 2
(c1)  ; => 3
(c2)  ; => 1  (独立したカウンタ)
(c2)  ; => 2

; スタックの実装
(define (make-stack)
  (let ((data '()))
    (define (push! x) (set! data (cons x data)))
    (define (pop!)
      (if (null? data)
          (error "Stack is empty")
          (let ((top (car data)))
            (set! data (cdr data))
            top)))
    (define (peek) (car data))
    (define (empty?) (null? data))
    (define (dispatch msg . args)
      (cond ((eq? msg 'push!) (push! (car args)))
            ((eq? msg 'pop!) (pop!))
            ((eq? msg 'peek) (peek))
            ((eq? msg 'empty?) (empty?))
            (else (error "Unknown message" msg))))
    dispatch))

(define s (make-stack))
(s 'push! 1)
(s 'push! 2)
(s 'push! 3)
(s 'pop!)    ; => 3
(s 'peek)    ; => 2

; アキュムレータ
(define (make-accumulator n)
  (lambda (amount)
    (set! n (+ n amount))
    n))

(define acc (make-accumulator 5))
(acc 10)   ; => 15
(acc 10)   ; => 25
```

サンプルファイル: `samples/03_functions/closures.scm`

---

## 11. let, let*, letrec

```scheme
; let: 並列バインド（相互参照不可）
(let ((x 1)
      (y 2))
  (+ x y))  ; => 3

; let*: 順次バインド（前の変数を参照可能）
(let* ((x 1)
       (y (+ x 1))
       (z (+ x y)))
  z)  ; => 3

; letrec: 相互再帰可能（関数定義に使う）
(letrec ((even? (lambda (n)
                  (if (= n 0) #t (odd? (- n 1)))))
         (odd?  (lambda (n)
                  (if (= n 0) #f (even? (- n 1))))))
  (list (even? 10) (odd? 7)))  ; => (#t #t)

; named let（ループに使える）
(let loop ((i 1) (acc 1))
  (if (> i 10)
      acc
      (loop (+ i 1) (* acc i))))  ; => 3628800 (10!)

; let の入れ子
(let ((x 10))
  (let ((x 20)
        (y x))   ; この x は外側の 10
    (+ x y)))    ; => 30
```

サンプルファイル: `samples/03_functions/let_forms.scm`

---

## 12. 文字列操作

```scheme
; 基本
(string-length "hello")        ; => 5
(string-ref "hello" 1)         ; => #\e
(substring "hello, world" 7 12) ; => "world"
(string-append "foo" "bar" "!")  ; => "foobar!"

; 変換
(string->list "abc")           ; => (#\a #\b #\c)
(list->string '(#\a #\b #\c))  ; => "abc"
(string->number "42")          ; => 42
(string->number "3.14")        ; => 3.14
(string->number "ff" 16)       ; => 255
(number->string 255 16)        ; => "ff"
(string->symbol "hello")       ; => hello
(symbol->string 'hello)        ; => "hello"

; 比較
(string=? "abc" "abc")   ; => #t
(string<? "abc" "abd")   ; => #t
(string>? "z" "a")       ; => #t
(string-ci=? "Hello" "hello")  ; => #t（大文字小文字無視）

; 変換
(string-upcase "hello")    ; => "HELLO"
(string-downcase "WORLD")  ; => "world"
(string-copy "hello")      ; 新しいコピー

; make-string
(make-string 5 #\x)   ; => "xxxxx"
(make-string 3)       ; 初期化なし

; 文字列を数字として処理
(for-each
  (lambda (c)
    (when (char-numeric? c)
      (display (- (char->integer c) (char->integer #\0)))
      (display " ")))
  (string->list "a1b2c3"))
; 表示: 1 2 3
```

サンプルファイル: `samples/02_data_structures/strings.scm`

---

## 13. 文字操作

```scheme
; 文字リテラル
#\a       ; 文字 a
#\A       ; 文字 A
#\0       ; 文字 0
#\space   ; スペース
#\newline ; 改行
#\tab     ; タブ

; 文字と整数の変換
(char->integer #\a)    ; => 97
(char->integer #\A)    ; => 65
(integer->char 65)     ; => #\A

; 文字比較
(char=? #\a #\a)       ; => #t
(char<? #\a #\b)       ; => #t
(char>? #\z #\a)       ; => #t
(char-ci=? #\a #\A)    ; => #t（大文字小文字無視）

; 文字述語
(char-alphabetic? #\a) ; => #t
(char-numeric? #\5)    ; => #t
(char-whitespace? #\space) ; => #t
(char-upper-case? #\A) ; => #t
(char-lower-case? #\a) ; => #t

; 文字変換
(char-upcase #\a)      ; => #\A
(char-downcase #\A)    ; => #\a

; 文字を使った処理
(define (count-vowels str)
  (length
    (filter (lambda (c)
              (member c '(#\a #\e #\i #\o #\u)))
            (string->list str))))

(count-vowels "hello world")  ; => 3
```

サンプルファイル: `samples/02_data_structures/characters.scm`

---

## 14. ベクタ

```scheme
; ベクタの作成
#(1 2 3)                 ; リテラル（immutable）
(vector 1 2 3)           ; => #(1 2 3)
(make-vector 5 0)        ; => #(0 0 0 0 0)
(make-vector 3)          ; 初期化なし

; アクセス
(vector-ref #(10 20 30) 1)   ; => 20
(vector-length #(a b c d))   ; => 4

; 変更
(define v (vector 1 2 3 4 5))
(vector-set! v 2 99)
v  ; => #(1 2 99 4 5)

(vector-fill! v 0)
v  ; => #(0 0 0 0 0)

; 変換
(vector->list #(1 2 3))     ; => (1 2 3)
(list->vector '(a b c))     ; => #(a b c)

; ベクタを使ったソート（バブルソート）
(define (vector-swap! v i j)
  (let ((tmp (vector-ref v i)))
    (vector-set! v i (vector-ref v j))
    (vector-set! v j tmp)))

(define (bubble-sort! v)
  (let ((n (vector-length v)))
    (let outer ((i 0))
      (when (< i (- n 1))
        (let inner ((j 0))
          (when (< j (- n i 1))
            (when (> (vector-ref v j) (vector-ref v (+ j 1)))
              (vector-swap! v j (+ j 1)))
            (inner (+ j 1))))
        (outer (+ i 1)))))
  v)

(bubble-sort! (vector 5 3 8 1 9 2 7 4 6))
; => #(1 2 3 4 5 6 7 8 9)
```

サンプルファイル: `samples/02_data_structures/vectors.scm`

---

## 15. 入出力

```scheme
; 画面への出力
(display "Hello, World!")  ; 文字列をそのまま表示
(newline)                  ; 改行
(write "Hello")            ; "Hello" (クォートあり)
(write #\a)               ; #\a

; 書式付き出力（Schemeにはprintfはない）
(define (printf fmt . args)
  (let loop ((chars (string->list fmt)) (args args))
    (cond
      ((null? chars) (void))
      ((and (char=? (car chars) #\~)
            (not (null? (cdr chars)))
            (char=? (cadr chars) #\a))
       (display (car args))
       (loop (cddr chars) (cdr args)))
      ((and (char=? (car chars) #\~)
            (not (null? (cdr chars)))
            (char=? (cadr chars) #\%))
       (newline)
       (loop (cddr chars) args))
      (else
       (display (car chars))
       (loop (cdr chars) args)))))

(printf "Name: ~a, Age: ~a~%" "Alice" 30)
; 表示: Name: Alice, Age: 30

; ファイル入出力
; (with-output-to-file "output.txt"
;   (lambda ()
;     (display "Hello, file!")
;     (newline)))

; (with-input-from-file "input.txt"
;   (lambda ()
;     (let loop ((line (read-line)))
;       (unless (eof-object? line)
;         (display line)
;         (newline)
;         (loop (read-line))))))

; 文字列からの読み取り（Scheme標準）
(define data (with-input-from-string "(+ 1 2 3)" read))
data  ; => (+ 1 2 3)  リストとして読み取られる

; read で式を読み取る
; (define expr (read))  ; ユーザーからの入力を読む
```

サンプルファイル: `samples/06_io/io_basics.scm`

---

## 16. do ループ

```scheme
; do ループの構文:
; (do ((var init step) ...)
;     (test result ...)
;   body ...)

; カウントアップ
(do ((i 0 (+ i 1)))
    ((= i 5) 'done)
  (display i)
  (display " "))
; 表示: 0 1 2 3 4

; 合計を計算
(do ((i 1 (+ i 1))
     (sum 0 (+ sum i)))
    ((> i 10) sum))
; => 55

; リストの反転
(define (my-reverse lst)
  (do ((l lst (cdr l))
       (r '() (cons (car l) r)))
      ((null? l) r)))

(my-reverse '(1 2 3 4 5))  ; => (5 4 3 2 1)

; ベクタの初期化
(define v (make-vector 10))
(do ((i 0 (+ i 1)))
    ((= i 10) v)
  (vector-set! v i (* i i)))
; => #(0 1 4 9 16 25 36 49 64 81)
```

サンプルファイル: `samples/04_recursion/do_loop.scm`

---

## 17. マクロ - define-syntax

```scheme
; 基本的なマクロ定義
(define-syntax my-when
  (syntax-rules ()
    ((my-when test expr ...)
     (if test (begin expr ...) (void)))))

(my-when (> 5 3)
  (display "5 is greater than 3")
  (newline))

; swap! マクロ
(define-syntax swap!
  (syntax-rules ()
    ((swap! a b)
     (let ((tmp a))
       (set! a b)
       (set! b tmp)))))

(define x 1)
(define y 2)
(swap! x y)
x  ; => 2
y  ; => 1

; while ループマクロ
(define-syntax while
  (syntax-rules ()
    ((while test body ...)
     (let loop ()
       (when test
         body ...
         (loop))))))

(define i 0)
(while (< i 5)
  (display i)
  (display " ")
  (set! i (+ i 1)))
; 表示: 0 1 2 3 4

; パターンマッチングの力
(define-syntax my-let
  (syntax-rules ()
    ((my-let ((var val) ...) body ...)
     ((lambda (var ...) body ...) val ...))))

(my-let ((x 10) (y 20))
  (+ x y))  ; => 30

; and/or マクロの実装
(define-syntax my-and
  (syntax-rules ()
    ((my-and) #t)
    ((my-and e) e)
    ((my-and e1 e2 ...)
     (if e1 (my-and e2 ...) #f))))

(my-and 1 2 3)   ; => 3
(my-and 1 #f 3)  ; => #f
```

サンプルファイル: `samples/05_macros/define_syntax.scm`

---

## 18. quasiquote

```scheme
; バッククォート（quasiquote）とカンマ（unquote）
`(1 2 3)            ; => (1 2 3)  （通常のクォートと同じ）
`(1 ,(+ 1 1) 3)     ; => (1 2 3)  （カンマで評価）

(define x 42)
`(the answer is ,x)  ; => (the answer is 42)

; unquote-splicing: リストを展開
(define nums '(1 2 3))
`(0 ,@nums 4)        ; => (0 1 2 3 4)

; マクロ作成での活用
(define-syntax my-list
  (syntax-rules ()
    ((my-list item ...)
     `(list ,item ...))))  ; 実際のマクロではこうは書かない（例示）

; コード生成
(define (make-let-form bindings body)
  `(let ,bindings ,@body))

(make-let-form '((x 10) (y 20)) '((+ x y)))
; => (let ((x 10) (y 20)) (+ x y))

; ネストしたquasiquote
`(a `(b ,(+ 1 2)))   ; => (a (quasiquote (b (unquote (+ 1 2)))))
```

サンプルファイル: `samples/05_macros/quasiquote.scm`

---

## 19. 継続 - call/cc

`call/cc`（`call-with-current-continuation`）は現在の継続を取り込みます。
sucheme では脱出継続（escape continuation）をサポートしています。

```scheme
; 基本的な使い方（早期脱出）
(define (find-first pred lst)
  (call/cc
    (lambda (return)
      (for-each (lambda (x)
                  (when (pred x) (return x)))
                lst)
      #f)))

(find-first even? '(1 3 5 4 7 9))  ; => 4
(find-first even? '(1 3 5 7 9))    ; => #f

; ループからの脱出
(define (search-matrix matrix target)
  (call/cc
    (lambda (found)
      (for-each
        (lambda (row)
          (for-each
            (lambda (elem)
              (when (= elem target) (found #t)))
            row))
        matrix)
      #f)))

(search-matrix '((1 2 3) (4 5 6) (7 8 9)) 5)  ; => #t
(search-matrix '((1 2 3) (4 5 6) (7 8 9)) 10) ; => #f

; 非局所脱出による例外処理
(define (safe-divide a b)
  (call/cc
    (lambda (escape)
      (when (= b 0) (escape 'division-by-zero))
      (/ a b))))

(safe-divide 10 2)   ; => 5
(safe-divide 10 0)   ; => division-by-zero
```

サンプルファイル: `samples/09_continuations/callcc_basics.scm`

---

## 20. 遅延評価 - delay/force

```scheme
; delay で評価を遅らせる
(define p (delay (begin
                   (display "evaluated!")
                   (newline)
                   42)))
; ここではまだ "evaluated!" は表示されない

(force p)  ; => 42  ここで初めて評価される
; 表示: evaluated!

(force p)  ; => 42  2回目はキャッシュされた値を返す
; 表示なし（再評価しない）

; 遅延リスト（ストリーム）
(define-syntax cons-stream
  (syntax-rules ()
    ((cons-stream head tail)
     (cons head (delay tail)))))

(define (stream-car s) (car s))
(define (stream-cdr s) (force (cdr s)))
(define stream-null '())
(define (stream-null? s) (null? s))

; 無限の整数ストリーム
(define (integers-from n)
  (cons-stream n (integers-from (+ n 1))))

(define naturals (integers-from 0))

(stream-car naturals)              ; => 0
(stream-car (stream-cdr naturals)) ; => 1

; ストリームからn個取る
(define (stream-take s n)
  (if (or (stream-null? s) (= n 0))
      '()
      (cons (stream-car s)
            (stream-take (stream-cdr s) (- n 1)))))

(stream-take naturals 10)  ; => (0 1 2 3 4 5 6 7 8 9)

; フィルタ
(define (stream-filter pred s)
  (cond ((stream-null? s) stream-null)
        ((pred (stream-car s))
         (cons-stream (stream-car s)
                      (stream-filter pred (stream-cdr s))))
        (else
         (stream-filter pred (stream-cdr s)))))

; 偶数ストリーム
(define evens (stream-filter even? (integers-from 0)))
(stream-take evens 5)  ; => (0 2 4 6 8)
```

サンプルファイル: `samples/07_advanced/delay_force.scm`

---

## 21. 多値 - values

```scheme
; values で複数の値を返す
(values 1 2 3)

; call-with-values で受け取る
(call-with-values
  (lambda () (values 1 2 3))
  (lambda (a b c) (+ a b c)))  ; => 6

; 商と余りを同時に返す
(define (div-mod a b)
  (values (quotient a b) (remainder a b)))

(call-with-values
  (lambda () (div-mod 17 5))
  (lambda (q r)
    (list 'quotient q 'remainder r)))
; => (quotient 3 remainder 2)

; let-values（マクロで実装可能）
(define-syntax let-values
  (syntax-rules ()
    ((let-values (((var ...) expr)) body ...)
     (call-with-values
       (lambda () expr)
       (lambda (var ...) body ...)))))

(let-values (((q r) (div-mod 17 5)))
  (display q) (display " ") (display r) (newline))
; 表示: 3 2
```

サンプルファイル: `samples/07_advanced/multiple_values.scm`

---

## 22. 数値の詳細

```scheme
; 型
(integer? 42)      ; => #t
(integer? 42.0)    ; => #t  (42.0は整数値)
(integer? 3.14)    ; => #f
(real? 3.14)       ; => #t
(rational? 1/3)    ; => #t
(number? "42")     ; => #f

; 正確数 vs 不正確数
(exact? 1/3)       ; => #t  有理数は正確
(exact? 42)        ; => #t  整数は正確
(inexact? 3.14)    ; => #t  浮動小数点は不正確

; 変換
(exact->inexact 1/3)   ; => 0.3333...
(inexact->exact 0.1)   ; => 3602879701896397/36028797018963968 (近似)

; GCD/LCM
(gcd 12 18)     ; => 6
(gcd 12 18 24)  ; => 6
(lcm 4 6)       ; => 12
(lcm 4 6 10)    ; => 60

; 数値の述語
(zero? 0)       ; => #t
(positive? 5)   ; => #t
(negative? -3)  ; => #t
(odd? 7)        ; => #t
(even? 8)       ; => #t

; 数値の基数表示
(number->string 255 16)  ; => "ff"
(number->string 255 2)   ; => "11111111"
(number->string 255 8)   ; => "377"
(string->number "ff" 16) ; => 255
(string->number "11111111" 2) ; => 255
```

サンプルファイル: `samples/01_basics/numbers.scm`

---

## 23. 等価述語

```scheme
; eq? : オブジェクトの同一性（ポインタ比較）
(eq? 'a 'a)        ; => #t  (同じシンボル)
(eq? '() '())      ; => #t  (空リストは同一)
(eq? #t #t)        ; => #t
(eq? (list 1) (list 1))  ; => #f  (異なるオブジェクト)

; eqv? : 値の等価性（数値・文字も含む）
(eqv? 42 42)       ; => #t
(eqv? #\a #\a)     ; => #t
(eqv? "abc" "abc") ; => 実装依存（通常 #f）

; equal? : 構造的等価性（再帰的に比較）
(equal? '(1 2 3) '(1 2 3))      ; => #t
(equal? #(1 2 3) #(1 2 3))      ; => #t
(equal? "hello" "hello")         ; => #t
(equal? '(1 (2 3)) '(1 (2 3)))  ; => #t

; 使い分け
; - eq?    : シンボル、真偽値、空リストの比較
; - eqv?   : 数値、文字の比較
; - equal? : リスト、文字列、ベクタの内容比較
```

---

## 24. テール位置と最適化

TCOが効く位置（テール位置）：

```scheme
; if の then/else
(define (f n)
  (if (= n 0)
      'done
      (f (- n 1))))  ; <- テール位置

; cond の各節
(define (g n)
  (cond ((= n 0) 'done)
        (else (g (- n 1)))))  ; <- テール位置

; and/or の最後の式
(define (h n)
  (and (> n 0) (h (- n 1))))  ; <- テール位置

; begin の最後の式
(define (k n)
  (begin
    (display n)
    (k (- n 1))))  ; <- テール位置

; let の body の最後の式
(define (m n)
  (let ((m (- n 1)))
    (m m)))  ; <- テール位置

; テール位置でない例
(define (not-tco n)
  (+ 1 (not-tco (- n 1))))  ; テール位置でない！スタックオーバーフローの可能性
```

---

## 25. 実用例 - データ処理

```scheme
; 連想リスト（alist）によるテーブル
(define db
  '((alice . ((age . 30) (job . "engineer")))
    (bob   . ((age . 25) (job . "designer")))
    (carol . ((age . 35) (job . "manager")))))

(define (lookup-person name)
  (cdr (assv name db)))

(define (get-field person field)
  (cdr (assv field person)))

(get-field (lookup-person 'alice) 'age)   ; => 30
(get-field (lookup-person 'bob) 'job)     ; => "designer"

; リストのソート（クイックソート）
(define (qsort lst)
  (if (or (null? lst) (null? (cdr lst)))
      lst
      (let ((pivot (car lst))
            (rest  (cdr lst)))
        (let ((smaller (filter (lambda (x) (< x pivot)) rest))
              (greater (filter (lambda (x) (>= x pivot)) rest)))
          (append (qsort smaller) (list pivot) (qsort greater))))))

(qsort '(5 3 8 1 9 2 7 4 6))  ; => (1 2 3 4 5 6 7 8 9)

; フラット化
(define (flatten lst)
  (cond ((null? lst) '())
        ((pair? (car lst))
         (append (flatten (car lst)) (flatten (cdr lst))))
        (else
         (cons (car lst) (flatten (cdr lst))))))

(flatten '(1 (2 3) (4 (5 6)) 7))  ; => (1 2 3 4 5 6 7)

; 集合演算
(define (set-union a b)
  (fold-right (lambda (x acc)
                (if (member x acc) acc (cons x acc)))
              a b))

(define (set-intersection a b)
  (filter (lambda (x) (member x b)) a))

(define (set-difference a b)
  (filter (lambda (x) (not (member x b))) a))

(set-union '(1 2 3) '(2 3 4 5))       ; => (1 2 3 4 5)
(set-intersection '(1 2 3 4) '(2 4 6)) ; => (2 4)
(set-difference '(1 2 3 4) '(2 4))     ; => (1 3)
```

サンプルファイル: `samples/08_practical/data_processing.scm`

---

## 26. 実用例 - アルゴリズム

```scheme
; 二分探索
(define (binary-search vec target)
  (let loop ((lo 0) (hi (- (vector-length vec) 1)))
    (if (> lo hi)
        -1
        (let ((mid (quotient (+ lo hi) 2)))
          (let ((val (vector-ref vec mid)))
            (cond ((= val target) mid)
                  ((< val target) (loop (+ mid 1) hi))
                  (else (loop lo (- mid 1)))))))))

(binary-search #(1 3 5 7 9 11 13 15) 7)   ; => 3
(binary-search #(1 3 5 7 9 11 13 15) 6)   ; => -1

; メモ化（動的計画法）
(define (memoize f)
  (let ((cache '()))
    (lambda args
      (let ((cached (assoc args cache)))
        (if cached
            (cdr cached)
            (let ((result (apply f args)))
              (set! cache (cons (cons args result) cache))
              result))))))

(define fib-memo
  (memoize
    (lambda (n)
      (if (< n 2)
          n
          (+ (fib-memo (- n 1)) (fib-memo (- n 2)))))))

(fib-memo 50)  ; => 12586269025 （高速）

; 素数の篩
(define (sieve n)
  (let ((primes (make-vector (+ n 1) #t)))
    (vector-set! primes 0 #f)
    (vector-set! primes 1 #f)
    (let loop ((i 2))
      (when (<= (* i i) n)
        (when (vector-ref primes i)
          (let inner ((j (* i i)))
            (when (<= j n)
              (vector-set! primes j #f)
              (inner (+ j i)))))
        (loop (+ i 1))))
    (let collect ((i 2) (acc '()))
      (if (> i n)
          (reverse acc)
          (collect (+ i 1)
                   (if (vector-ref primes i)
                       (cons i acc)
                       acc))))))

(sieve 50)
; => (2 3 5 7 11 13 17 19 23 29 31 37 41 43 47)

; 塔のハノイ
(define (hanoi n from to via)
  (when (> n 0)
    (hanoi (- n 1) from via to)
    (display (list 'move 'disk n 'from from 'to to))
    (newline)
    (hanoi (- n 1) via to from)))

(hanoi 3 'A 'C 'B)
```

サンプルファイル: `samples/08_practical/algorithms.scm`

---

## まとめ

このチュートリアルでは sucheme の主要機能をカバーしました：

- 基本的な式と型
- 制御フロー（if/cond/case/and/or）
- 関数とクロージャ
- リスト・文字列・ベクタ操作
- 再帰と末尾呼び出し最適化
- 高階関数（map/filter/fold）
- マクロ（define-syntax/syntax-rules）
- 継続（call/cc）
- 遅延評価（delay/force）
- 多値（values）

さらに詳しいサンプルは `samples/` ディレクトリを参照してください。
