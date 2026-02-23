; 08_practical/practical.scm - 実用的なプログラム例

; スタック実装
(define (make-stack)
  (let ((data '()))
    (define (push! x)
      (set! data (cons x data)))
    (define (pop!)
      (if (null? data)
          (error "Stack underflow")
          (let ((top (car data)))
            (set! data (cdr data))
            top)))
    (define (peek)
      (if (null? data)
          (error "Stack empty")
          (car data)))
    (define (empty?) (null? data))
    (define (size) (length data))
    (lambda (msg . args)
      (case msg
        ((push!)  (push! (car args)))
        ((pop!)   (pop!))
        ((peek)   (peek))
        ((empty?) (empty?))
        ((size)   (size))
        (else     (error "Unknown message" msg))))))

(define s (make-stack))
(s 'push! 1)
(s 'push! 2)
(s 'push! 3)
(display (s 'size))    (newline)   ; 3
(display (s 'pop!))    (newline)   ; 3
(display (s 'peek))    (newline)   ; 2
(display (s 'empty?))  (newline)   ; #f

; 簡単なパーサー
(define (tokenize str)
  (let loop ((chars (string->list str)) (current '()) (tokens '()))
    (cond
      ((null? chars)
       (reverse (if (null? current)
                    tokens
                    (cons (list->string (reverse current)) tokens))))
      ((char-whitespace? (car chars))
       (loop (cdr chars)
             '()
             (if (null? current)
                 tokens
                 (cons (list->string (reverse current)) tokens))))
      (else
       (loop (cdr chars) (cons (car chars) current) tokens)))))

(display (tokenize "hello world foo bar")) (newline)

; 簡単な電卓
(define (calc expr)
  (cond
    ((number? expr) expr)
    ((pair? expr)
     (let ((op (car expr))
           (a  (calc (cadr expr)))
           (b  (calc (caddr expr))))
       (cond
         ((eq? op '+) (+ a b))
         ((eq? op '-) (- a b))
         ((eq? op '*) (* a b))
         ((eq? op '/) (/ a b))
         (else (error "Unknown operator" op)))))
    (else (error "Invalid expression" expr))))

(display (calc '(+ (* 3 4) (- 10 5)))) (newline)  ; 17
(display (calc '(* (+ 1 2) (+ 3 4))))  (newline)  ; 21
