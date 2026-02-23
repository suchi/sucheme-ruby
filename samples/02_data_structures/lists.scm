; 02_data_structures/lists.scm - リストとベクタ

(display "--- リスト操作 ---") (newline)

; リストの作成
(define lst '(1 2 3 4 5))
(display lst) (newline)

; 基本操作
(display (car lst)) (newline)       ; 1
(display (cdr lst)) (newline)       ; (2 3 4 5)
(display (cadr lst)) (newline)      ; 2
(display (caddr lst)) (newline)     ; 3
(display (length lst)) (newline)    ; 5

; リスト構築
(display (cons 0 lst)) (newline)    ; (0 1 2 3 4 5)
(display (list 'a 'b 'c)) (newline)
(display (append '(1 2) '(3 4) '(5 6))) (newline)
(display (reverse lst)) (newline)

; リスト変換
(display (map (lambda (x) (* x x)) lst)) (newline)
(display (filter odd? lst)) (newline)
(display (fold-right + 0 lst)) (newline)

; 連想リスト
(display "--- 連想リスト ---") (newline)
(define alist '((a . 1) (b . 2) (c . 3)))
(display (assoc 'b alist)) (newline)   ; (b . 2)
(display (assq 'c alist)) (newline)    ; (c . 3)

; ベクタ
(display "--- ベクタ ---") (newline)
(define v (vector 10 20 30 40 50))
(display v) (newline)
(display (vector-ref v 2)) (newline)   ; 30
(vector-set! v 2 99)
(display v) (newline)
(display (vector->list v)) (newline)
