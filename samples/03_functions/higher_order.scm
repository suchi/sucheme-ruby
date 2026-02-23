; 03_functions/higher_order.scm - 高階関数

; 関数合成
(define (compose f g)
  (lambda (x) (f (g x))))

(define (compose* . fns)
  (if (null? fns)
      (lambda (x) x)
      (let ((f (car fns))
            (rest (apply compose* (cdr fns))))
        (lambda (x) (f (rest x))))))

(define double   (lambda (x) (* x 2)))
(define inc      (lambda (x) (+ x 1)))
(define square   (lambda (x) (* x x)))
(define double-then-inc (compose inc double))
(define pipeline (compose* inc square double))

(display (double-then-inc 5)) (newline)  ; 11
(display (pipeline 3)) (newline)          ; (3*2)^2 + 1 = 37

; カリー化
(define (curry2 f)
  (lambda (x) (lambda (y) (f x y))))

(define add (curry2 +))
(define add5 (add 5))
(display (add5 3)) (newline)  ; 8
(display (add5 10)) (newline) ; 15

; 部分適用
(define (partial f . args)
  (lambda rest (apply f (append args rest))))

(define double* (partial * 2))
(define add10   (partial + 10))
(display (map double* '(1 2 3 4 5))) (newline)
(display (map add10   '(1 2 3 4 5))) (newline)

; フォールド
(define (my-fold-right f init lst)
  (if (null? lst)
      init
      (f (car lst) (my-fold-right f init (cdr lst)))))

(define (my-fold-left f acc lst)
  (if (null? lst)
      acc
      (my-fold-left f (f acc (car lst)) (cdr lst))))

(display (my-fold-right cons '() '(1 2 3 4 5))) (newline)
(display (my-fold-left (lambda (acc x) (cons x acc)) '() '(1 2 3 4 5))) (newline)
