# frozen_string_literal: true

require 'spec_helper'

# R5RS compliance tests based on the R5RS standard
RSpec.describe 'R5RS Compliance' do
  let(:env) { Sucheme::Evaluator.make_global_env }

  def eval_str(source)
    Sucheme::Evaluator.eval_source(source, env)
  end

  # Section 4.1 - Primitive expression types
  describe '4.1 Primitive expression types' do
    it '4.1.1 Variable references' do
      eval_str('(define x 28)')
      expect(eval_str('x')).to eq(28)
    end

    it '4.1.2 Literal expressions' do
      expect(eval_str("(quote a)")).to eq(Sucheme::SchemeSymbol.intern('a'))
      expect(eval_str("(quote (a b c))").to_a.map(&:name)).to eq(['a', 'b', 'c'])
      expect(eval_str("(quote (+ 1 2))")).to be_a(Sucheme::SchemePair)
    end

    it '4.1.3 Procedure calls' do
      expect(eval_str('(+ 3 4)')).to eq(7)
      expect(eval_str('((if #f + *) 3 4)')).to eq(12)
    end

    it '4.1.4 Lambda' do
      expect(eval_str('((lambda (x) (+ x x)) 4)')).to eq(8)
      eval_str('(define reverse-subtract (lambda (x y) (- y x)))')
      expect(eval_str('(reverse-subtract 7 10)')).to eq(3)
      eval_str('(define add4 (let ((x 4)) (lambda (y) (+ x y))))')
      expect(eval_str('(add4 6)')).to eq(10)
    end

    it '4.1.4 Lambda with rest args' do
      expect(eval_str('((lambda x x) 3 4 5 6)').to_a).to eq([3, 4, 5, 6])
      expect(eval_str('((lambda (x y . z) z) 3 4 5 6)').to_a).to eq([5, 6])
    end

    it '4.1.5 Conditionals' do
      expect(eval_str('(if (> 3 2) "yes" "no")')).to eq('yes')
      expect(eval_str('(if (> 2 3) "yes" "no")')).to eq('no')
      expect(eval_str('(if (> 3 2) (- 3 2) (+ 3 2))')).to eq(1)
    end

    it '4.1.6 Assignments' do
      eval_str('(define x 2)')
      expect(eval_str('(+ x 1)')).to eq(3)
      eval_str('(set! x 4)')
      expect(eval_str('(+ x 1)')).to eq(5)
    end
  end

  # Section 4.2 - Derived expression types
  describe '4.2 Derived expression types' do
    it '4.2.1 Cond' do
      expect(eval_str('(cond ((> 3 2) "greater") ((< 3 2) "less"))')).to eq('greater')
      expect(eval_str('(cond ((> 2 3) "greater") ((< 2 3) "less"))')).to eq('less')
      expect(eval_str('(cond ((> 2 3) "greater") (else "other"))')).to eq('other')
    end

    it '4.2.1 Case' do
      result = eval_str('(case (* 2 3) ((2 3 5 7) "prime") ((1 4 6 8 9) "composite"))')
      expect(result).to eq('composite')
      result = eval_str('(case (car \'(c d)) ((a e i o u) "vowel") ((w y) "semivowel") (else "other"))')
      expect(result).to eq('other')
    end

    it '4.2.1 And' do
      expect(eval_str('(and (= 2 2) (> 2 1))')).to eq(true)
      expect(eval_str('(and (= 2 2) (< 2 1))')).to eq(false)
      expect(eval_str("(and 1 2 'c '(f g))").to_a.map(&:name)).to eq(['f', 'g'])
      expect(eval_str('(and)')).to eq(true)
    end

    it '4.2.1 Or' do
      expect(eval_str("(or (= 2 2) (> 2 1))")).to eq(true)
      expect(eval_str("(or (= 2 2) (< 2 1))")).to eq(true)
      expect(eval_str('(or #f #f #f)')).to eq(false)
      result = eval_str("(or (memv 2 '(1 2 3)) #f)")
      expect(result.car).to eq(2)
    end

    it '4.2.2 Let' do
      expect(eval_str('(let ((x 2) (y 3)) (* x y))')).to eq(6)
      expect(eval_str('(let ((x 2) (y 3)) (let ((x 7) (z (+ x y))) (* z x)))')).to eq(35)
    end

    it '4.2.2 Let*' do
      expect(eval_str('(let* ((x 1) (y (+ x 1))) y)')).to eq(2)
    end

    it '4.2.2 Letrec' do
      code = '(letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
                       (odd?  (lambda (n) (if (= n 0) #f (even? (- n 1))))))
               (even? 88))'
      expect(eval_str(code)).to eq(true)
    end

    it '4.2.3 Begin' do
      eval_str('(define x 0)')
      eval_str('(begin (set! x 5) (+ x 1))')
      expect(eval_str('x')).to eq(5)
    end

    it '4.2.4 Iteration (do)' do
      result = eval_str('(do ((vec (make-vector 5))
                              (i 0 (+ i 1)))
                             ((= i 5) vec)
                           (vector-set! vec i (* i i)))')
      expect(result[0]).to eq(0)
      expect(result[1]).to eq(1)
      expect(result[2]).to eq(4)
      expect(result[3]).to eq(9)
      expect(result[4]).to eq(16)
    end

    it '4.2.4 Named let' do
      expect(eval_str('(let ((result (let loop ((i 1) (prod 1))
                                       (if (> i 5) prod (loop (+ i 1) (* prod i)))))
                        ) result)')).to eq(120)
    end

    it '4.2.5 Delay and force' do
      eval_str('(define count 0)')
      eval_str('(define x 0)')
      eval_str('(define p (delay (begin (set! count (+ count 1)) (* x 3))))')
      eval_str('(define x 5)')
      expect(eval_str('(force p)')).to eq(15)
      expect(eval_str('(force p)')).to eq(15)  # memoized
      expect(eval_str('count')).to eq(1)
    end
  end

  # Section 6 - Standard procedures
  describe '6.1 Equivalence predicates' do
    it 'eqv?' do
      expect(eval_str("(eqv? 'a 'a)")).to eq(true)
      expect(eval_str("(eqv? 'a 'b)")).to eq(false)
      expect(eval_str("(eqv? '() '())")).to eq(true)
      expect(eval_str('(eqv? 100 100)')).to eq(true)
      expect(eval_str('(eqv? #t #t)')).to eq(true)
      expect(eval_str("(eqv? (cons 1 2) (cons 1 2))")).to eq(false)
    end

    it 'equal?' do
      expect(eval_str("(equal? 'a 'a)")).to eq(true)
      expect(eval_str("(equal? '(a) '(a))")).to eq(true)
      expect(eval_str("(equal? '(a (b) c) '(a (b) c))")).to eq(true)
      expect(eval_str('(equal? "abc" "abc")')).to eq(true)
      expect(eval_str('(equal? 2 2)')).to eq(true)
      expect(eval_str('(equal? #(1 2 3) #(1 2 3))')).to eq(true)
    end
  end

  describe '6.2 Numbers' do
    it 'number predicates' do
      expect(eval_str('(complex? 3)')).to eq(true)
      expect(eval_str('(real? 3)')).to eq(true)
      expect(eval_str('(rational? 3)')).to eq(true)
      expect(eval_str('(integer? 3)')).to eq(true)
    end

    it 'exact/inexact' do
      expect(eval_str('(exact? 3)')).to eq(true)
      expect(eval_str('(inexact? 3.0)')).to eq(true)
    end

    it 'number comparisons' do
      expect(eval_str('(< 1 2 3)')).to eq(true)
      expect(eval_str('(> 3 2 1)')).to eq(true)
      expect(eval_str('(<= 1 1 2)')).to eq(true)
    end

    it 'arithmetic' do
      expect(eval_str('(+ 3 4)')).to eq(7)
      expect(eval_str('(+ 3)')).to eq(3)
      expect(eval_str('(+)')).to eq(0)
      expect(eval_str('(* 4)')).to eq(4)
      expect(eval_str('(*)')).to eq(1)
      expect(eval_str('(- 3 4)')).to eq(-1)
      expect(eval_str('(- 3 4 5)')).to eq(-6)
      expect(eval_str('(- 3)')).to eq(-3)
    end

    it 'floor, ceiling, round, truncate' do
      expect(eval_str('(floor 3.5)')).to eq(3.0)
      expect(eval_str('(ceiling 3.5)')).to eq(4.0)
      expect(eval_str('(round 3.5)')).to eq(4.0)
      expect(eval_str('(round 4.5)')).to eq(4.0)
      expect(eval_str('(truncate 3.5)')).to eq(3.0)
    end
  end

  describe '6.3 Other data types' do
    it '6.3.2 Pairs' do
      expect(eval_str("(pair? '(a . b))")).to eq(true)
      expect(eval_str("(pair? '(a b c))")).to eq(true)
      expect(eval_str("(pair? '())")).to eq(false)
      result = eval_str("(cons 'a '())")
      expect(result.car.name).to eq('a')
      expect(eval_str("(car '(a b c))").name).to eq('a')
    end

    it '6.3.3 Symbols' do
      expect(eval_str("(symbol? 'foo)")).to eq(true)
      expect(eval_str("(symbol->string 'flying-fish)")).to eq('flying-fish')
      result = eval_str('(string->symbol "mISSISSIppi")')
      expect(result.name).to eq('mISSISSIppi')
    end

    it '6.3.4 Characters' do
      expect(eval_str('(char? #\a)')).to eq(true)
      expect(eval_str('(char=? #\a #\a)')).to eq(true)
      expect(eval_str('(char<? #\a #\b)')).to eq(true)
      expect(eval_str('(char->integer #\A)')).to eq(65)
      expect(eval_str('(char-upcase #\a)').char).to eq('A')
    end

    it '6.3.5 Strings' do
      expect(eval_str('(string-length "abc")')).to eq(3)
      expect(eval_str('(substring "abcde" 1 3)')).to eq('bc')
      expect(eval_str('(string-append "foo" "bar")')).to eq('foobar')
      result = eval_str('(string->list "abc")')
      expect(result.to_a.map(&:char)).to eq(['a', 'b', 'c'])
    end

    it '6.3.6 Vectors' do
      result = eval_str('(make-vector 5 0)')
      expect(result.length).to eq(5)
      expect(result[0]).to eq(0)
      expect(eval_str('(vector-length (vector 1 2 3))')).to eq(3)
      result2 = eval_str('(vector 1 2 3)')
      expect(result2[0]).to eq(1)
    end
  end

  describe '6.4 Control features' do
    it 'apply' do
      expect(eval_str("(apply + '(3 4))")).to eq(7)
      expect(eval_str("(apply + 1 2 '(3 4))")).to eq(10)
      expect(eval_str("(apply list '(3 4))").to_a).to eq([3, 4])
    end

    it 'map' do
      result = eval_str("(map car '((a b) (d e) (g h i)))")
      expect(result.to_a.map(&:name)).to eq(['a', 'd', 'g'])
      result2 = eval_str("(map + '(1 2 3) '(4 5 6))")
      expect(result2.to_a).to eq([5, 7, 9])
    end

    it 'for-each' do
      expect { eval_str("(for-each display '(a b c))") }.to output('abc').to_stdout
    end

    it 'call/cc basic' do
      expect(eval_str('(call-with-current-continuation (lambda (k) 42))')).to eq(42)
      expect(eval_str('(call-with-current-continuation (lambda (k) (k 42) 100))')).to eq(42)
    end

    it 'call/cc product with early exit' do
      code = '(define (product . ls)
                (call/cc
                  (lambda (break)
                    (let f ((l ls))
                      (cond ((null? l) 1)
                            ((= (car l) 0) (break 0))
                            (else (* (car l) (f (cdr l)))))))))
              (product 1 2 3 4 5)'
      expect(eval_str(code)).to eq(120)
    end
  end

  describe 'tail calls' do
    it 'proper tail recursion in named let' do
      result = eval_str('(let loop ((n 500000) (acc 0))
                           (if (= n 0) acc (loop (- n 1) (+ acc 1))))')
      expect(result).to eq(500_000)
    end

    it 'proper tail recursion in letrec' do
      code = '(letrec ((count (lambda (n)
                                (if (= n 0) "done" (count (- n 1))))))
               (count 500000))'
      expect(eval_str(code)).to eq('done')
    end
  end

  describe 'macros' do
    it 'let expands correctly' do
      expect(eval_str('(let ((x 1) (y 2)) (+ x y))')).to eq(3)
    end

    it 'let* sequential bindings' do
      expect(eval_str('(let* ((x 1) (y (+ x 1)) (z (+ y 1))) z)')).to eq(3)
    end

    it 'custom and macro' do
      code = '(define-syntax my-and
                (syntax-rules ()
                  ((my-and) #t)
                  ((my-and e) e)
                  ((my-and e1 e2 ...)
                   (if e1 (my-and e2 ...) #f))))
              (my-and #t #t #t)'
      expect(eval_str(code)).to eq(true)
    end
  end
end
