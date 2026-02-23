; 07_advanced/continuations.scm - 継続と制御フロー

; 早期終了
(define (find-first pred lst)
  (call/cc
    (lambda (return)
      (for-each
        (lambda (x)
          (when (pred x) (return x)))
        lst)
      #f)))

(display (find-first even? '(1 3 5 6 7 8))) (newline)  ; 6
(display (find-first even? '(1 3 5 7 9)))   (newline)  ; #f

; generator パターン
(define (make-generator lst)
  (define saved-k #f)
  (define items lst)
  (lambda ()
    (call/cc
      (lambda (return)
        (when (null? items)
          (return 'done))
        (let ((val (car items)))
          (set! items (cdr items))
          (return val))))))

(define gen (make-generator '(1 2 3 4 5)))
(display (gen)) (newline)  ; 1
(display (gen)) (newline)  ; 2
(display (gen)) (newline)  ; 3

; 例外処理の模倣
(define (with-error-handler handler thunk)
  (call/cc
    (lambda (k)
      (define (my-error msg)
        (k (handler msg)))
      (thunk my-error))))

(define result
  (with-error-handler
    (lambda (msg) (string-append "Error: " msg))
    (lambda (err)
      (display "Computing...")
      (newline)
      42)))

(display result) (newline)  ; 42
