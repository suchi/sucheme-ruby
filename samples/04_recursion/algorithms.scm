; 04_recursion/algorithms.scm - 再帰アルゴリズム

; フィボナッチ数列（末尾再帰）
(define (fib n)
  (let loop ((i n) (a 0) (b 1))
    (if (= i 0)
        a
        (loop (- i 1) b (+ a b)))))

(display "Fibonacci:") (newline)
(display (map fib '(0 1 2 3 4 5 6 7 8 9 10))) (newline)

; 階乗（末尾再帰）
(define (factorial n)
  (let loop ((i n) (acc 1))
    (if (= i 0) acc (loop (- i 1) (* acc i)))))

(display "10! = ") (display (factorial 10)) (newline)
(display "20! = ") (display (factorial 20)) (newline)

; マージソート
(define (merge-sort lst)
  (define (merge a b)
    (cond ((null? a) b)
          ((null? b) a)
          ((< (car a) (car b))
           (cons (car a) (merge (cdr a) b)))
          (else
           (cons (car b) (merge a (cdr b))))))
  (define (split lst)
    (let loop ((l lst) (a '()) (b '()))
      (if (null? l)
          (values a b)
          (loop (cdr l) b (cons (car l) a)))))
  (if (or (null? lst) (null? (cdr lst)))
      lst
      (let-values (((a b) (split lst)))
        (merge (merge-sort a) (merge-sort b)))))

(display "Merge sort:") (newline)
(display (merge-sort '(5 3 8 1 9 2 7 4 6))) (newline)

; 木構造の探索
(define (make-tree val left right) (list val left right))
(define (tree-val t) (car t))
(define (tree-left t) (cadr t))
(define (tree-right t) (caddr t))
(define (tree-leaf? t) (and (null? (tree-left t)) (null? (tree-right t))))

(define (tree-insert t val)
  (if (null? t)
      (make-tree val '() '())
      (cond ((< val (tree-val t))
             (make-tree (tree-val t) (tree-insert (tree-left t) val) (tree-right t)))
            ((> val (tree-val t))
             (make-tree (tree-val t) (tree-left t) (tree-insert (tree-right t) val)))
            (else t))))

(define (tree-inorder t)
  (if (null? t)
      '()
      (append (tree-inorder (tree-left t))
              (list (tree-val t))
              (tree-inorder (tree-right t)))))

(define bst
  (fold-left tree-insert '() '(5 3 7 1 4 6 8 2)))

(display "BST inorder:") (newline)
(display (tree-inorder bst)) (newline)
