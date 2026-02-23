; 01_basics/variables.scm - 変数と算術の基礎

; 変数定義
(define x 10)
(define y 20)
(define z (+ x y))

(display "x = ") (display x) (newline)
(display "y = ") (display y) (newline)
(display "z = x + y = ") (display z) (newline)

; 算術演算
(display "--- 算術演算 ---") (newline)
(display (+ 1 2 3 4 5)) (newline)       ; 15
(display (* 2 3 4)) (newline)           ; 24
(display (- 100 30 20)) (newline)       ; 50
(display (/ 100 4)) (newline)           ; 25
(display (quotient 17 5)) (newline)     ; 3
(display (remainder 17 5)) (newline)    ; 2
(display (modulo -7 3)) (newline)       ; 2
(display (expt 2 10)) (newline)         ; 1024
(display (sqrt 144)) (newline)          ; 12

; 文字列
(display "--- 文字列 ---") (newline)
(define greeting "Hello, World!")
(display greeting) (newline)
(display (string-length greeting)) (newline)
(display (substring greeting 0 5)) (newline)
(display (string-append "foo" "bar" "baz")) (newline)
(display (string-upcase "hello")) (newline)
(display (string-downcase "WORLD")) (newline)
