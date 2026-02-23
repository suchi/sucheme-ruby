; 10_exercises/exercises.scm - プログラミング演習

; 問題1: リストの最大値
(define (list-max lst)
  (if (null? (cdr lst))
      (car lst)
      (max (car lst) (list-max (cdr lst)))))

(display (list-max '(3 1 4 1 5 9 2 6))) (newline)  ; 9

; 問題2: フラット化
(define (flatten lst)
  (cond ((null? lst) '())
        ((pair? (car lst))
         (append (flatten (car lst)) (flatten (cdr lst))))
        (else
         (cons (car lst) (flatten (cdr lst))))))

(display (flatten '(1 (2 (3 4) 5) (6 7)))) (newline)  ; (1 2 3 4 5 6 7)

; 問題3: 冪集合
(define (power-set lst)
  (if (null? lst)
      '(())
      (let ((rest (power-set (cdr lst))))
        (append rest
                (map (lambda (subset) (cons (car lst) subset))
                     rest)))))

(display (power-set '(1 2 3))) (newline)

; 問題4: パーミュテーション
(define (permutations lst)
  (if (null? lst)
      '(())
      (apply append
             (map (lambda (elem)
                    (map (lambda (perm) (cons elem perm))
                         (permutations (filter (lambda (x) (not (eq? x elem))) lst))))
                  lst))))

(display (length (permutations '(1 2 3 4)))) (newline)  ; 24

; 問題5: ハノイの塔
(define (hanoi n from to via)
  (when (> n 0)
    (hanoi (- n 1) from via to)
    (display (string-append "Move disk " (number->string n)
                            " from " (symbol->string from)
                            " to " (symbol->string to)))
    (newline)
    (hanoi (- n 1) via to from)))

(display "=== ハノイの塔 (3枚) ===") (newline)
(hanoi 3 'A 'C 'B)
