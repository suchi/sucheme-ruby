; 09_continuations/callcc_examples.scm - call/cc の応用

; コルーチン
(define (make-coroutine thunk)
  (define saved-k #f)
  (define result #f)
  (define done #f)
  (lambda ()
    (if done
        'done
        (call/cc
          (lambda (caller-k)
            (if saved-k
                (saved-k caller-k)
                (begin
                  (set! result
                        (thunk (lambda (val)
                                 (call/cc
                                   (lambda (k)
                                     (set! saved-k k)
                                     (caller-k val))))))
                  (set! done #t)
                  result)))))))

; バックトラッキング
(define fail #f)

(define (amb . choices)
  (call/cc
    (lambda (k)
      (let loop ((remaining choices))
        (if (null? remaining)
            (fail 'exhausted)
            (begin
              (let ((old-fail fail))
                (set! fail (lambda (_)
                              (set! fail old-fail)
                              (loop (cdr remaining)))))
              (k (car remaining))))))))

(define (require p)
  (when (not p) (fail 'fail)))

; 非決定的プログラミング
(define solution
  (call/cc
    (lambda (k)
      (set! fail (lambda (_) (k 'no-solution)))
      (let ((x (amb 1 2 3 4 5))
            (y (amb 1 2 3 4 5)))
        (require (= (+ x y) 7))
        (require (< x y))
        (list x y)))))

(display "x + y = 7, x < y: ") (display solution) (newline)

; 早期終了のまとめ
(define (find-all pred lst)
  (let loop ((l lst) (acc '()))
    (if (null? l)
        (reverse acc)
        (loop (cdr l)
              (if (pred (car l))
                  (cons (car l) acc)
                  acc)))))

(display (find-all even? '(1 2 3 4 5 6 7 8 9 10))) (newline)
