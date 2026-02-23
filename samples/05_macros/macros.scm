; 05_macros/macros.scm - マクロの定義と使用

; シンプルなマクロ
(define-syntax swap!
  (syntax-rules ()
    ((swap! a b)
     (let ((tmp a))
       (set! a b)
       (set! b tmp)))))

(define x 1) (define y 2)
(swap! x y)
(display x) (display " ") (display y) (newline)  ; 2 1

; ループマクロ
(define-syntax repeat
  (syntax-rules ()
    ((repeat n body ...)
     (let loop ((i n))
       (when (> i 0)
         body ...
         (loop (- i 1)))))))

(repeat 3 (display "Hello! ") )
(newline)

; アサーションマクロ
(define-syntax assert
  (syntax-rules ()
    ((assert expr)
     (when (not expr)
       (error "Assertion failed" 'expr)))
    ((assert expr msg)
     (when (not expr)
       (error msg 'expr)))))

(assert (= (+ 1 1) 2))
(assert (> 5 3) "5 should be greater than 3")
(display "All assertions passed") (newline)

; パターンマッチング風マクロ
(define-syntax match-list
  (syntax-rules (=>)
    ((match-list lst
       (pattern => result) ...)
     (cond
       ((equal? lst 'pattern) result)
       ...
       (else (error "No match" lst))))))

; let-bindingマクロ
(define-syntax bind
  (syntax-rules (<-)
    ((bind (var <- expr) body ...)
     (let ((var expr)) body ...))
    ((bind (var <- expr) rest ... body ...)
     (let ((var expr)) (bind rest ... body ...)))))

(bind (a <- 1)
      (b <- (+ a 1))
      (c <- (* b 3))
      (display (list a b c)) (newline))
