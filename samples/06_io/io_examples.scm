; 06_io/io_examples.scm - I/O操作

; 基本出力
(display "=== 基本出力 ===") (newline)
(display "display: 文字列をそのまま表示") (newline)
(write "write: 文字列を引用符付きで表示") (newline)
(display #\a) (display " ") (write #\a) (newline)
(display '(1 2 3)) (newline)

; 文字列ポート
(display "=== 文字列ポート ===") (newline)
(define out-port (open-output-string))
(display "hello " out-port)
(display "world" out-port)
(define result (get-output-string out-port))
(display "Captured: ") (display result) (newline)

; 入力ポートから読み込み
(define in-port (open-input-string "(+ 1 2) foo 42"))
(display (read in-port)) (newline)  ; (+ 1 2)
(display (read in-port)) (newline)  ; foo
(display (read in-port)) (newline)  ; 42
(display (eof-object? (read in-port))) (newline)  ; #t
