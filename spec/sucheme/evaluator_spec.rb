# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sucheme::Evaluator do
  let(:env) { described_class.make_global_env }

  def eval_str(source, e = env)
    described_class.eval_source(source, e)
  end

  describe 'self-evaluating forms' do
    it 'evaluates integers' do
      expect(eval_str('42')).to eq(42)
    end

    it 'evaluates floats' do
      expect(eval_str('3.14')).to eq(3.14)
    end

    it 'evaluates strings' do
      expect(eval_str('"hello"')).to eq('hello')
    end

    it 'evaluates booleans' do
      expect(eval_str('#t')).to eq(true)
      expect(eval_str('#f')).to eq(false)
    end

    it 'evaluates characters' do
      result = eval_str('#\a')
      expect(result).to be_a(Sucheme::SchemeChar)
    end
  end

  describe 'quote' do
    it 'quotes symbols' do
      result = eval_str("'foo")
      expect(result).to be_a(Sucheme::SchemeSymbol)
      expect(result.name).to eq('foo')
    end

    it 'quotes lists' do
      result = eval_str("'(1 2 3)")
      expect(result).to be_a(Sucheme::SchemePair)
    end

    it 'quotes empty list' do
      result = eval_str("'()")
      expect(result).to be_a(Sucheme::SchemeNull)
    end
  end

  describe 'if' do
    it 'evaluates true branch' do
      expect(eval_str('(if #t 1 2)')).to eq(1)
    end

    it 'evaluates false branch' do
      expect(eval_str('(if #f 1 2)')).to eq(2)
    end

    it 'only false is falsy' do
      expect(eval_str('(if 0 1 2)')).to eq(1)
      expect(eval_str('(if "" 1 2)')).to eq(1)
      expect(eval_str('(if \'() 1 2)')).to eq(1)
    end

    it 'returns void when no else branch and condition false' do
      result = eval_str('(if #f 1)')
      expect(result).to be_a(Sucheme::SchemeVoid)
    end
  end

  describe 'define' do
    it 'defines a variable' do
      eval_str('(define x 10)', env)
      expect(eval_str('x', env)).to eq(10)
    end

    it 'defines a function shorthand' do
      eval_str('(define (square x) (* x x))', env)
      expect(eval_str('(square 5)', env)).to eq(25)
    end

    it 'defines variadic function' do
      eval_str('(define (f . args) args)', env)
      result = eval_str('(f 1 2 3)', env)
      expect(result.to_a).to eq([1, 2, 3])
    end
  end

  describe 'lambda' do
    it 'creates a procedure' do
      result = eval_str('(lambda (x) x)')
      expect(result).to be_a(Sucheme::SchemeProcedure)
    end

    it 'applies lambda' do
      expect(eval_str('((lambda (x) (* x x)) 5)')).to eq(25)
    end

    it 'handles closures' do
      eval_str('(define (make-adder n) (lambda (x) (+ x n)))', env)
      eval_str('(define add5 (make-adder 5))', env)
      expect(eval_str('(add5 3)', env)).to eq(8)
    end

    it 'handles rest parameters' do
      result = eval_str('((lambda (x . rest) rest) 1 2 3)')
      expect(result.to_a).to eq([2, 3])
    end

    it 'handles only rest parameter' do
      result = eval_str('((lambda args args) 1 2 3)')
      expect(result.to_a).to eq([1, 2, 3])
    end
  end

  describe 'begin' do
    it 'evaluates sequence and returns last' do
      expect(eval_str('(begin 1 2 3)')).to eq(3)
    end

    it 'executes side effects' do
      eval_str('(define x 0)', env)
      eval_str('(begin (set! x 1) (set! x 2))', env)
      expect(eval_str('x', env)).to eq(2)
    end
  end

  describe 'set!' do
    it 'mutates binding' do
      eval_str('(define x 1)', env)
      eval_str('(set! x 42)', env)
      expect(eval_str('x', env)).to eq(42)
    end

    it 'raises on unbound variable' do
      expect { eval_str('(set! unbound-var 1)') }.to raise_error(Sucheme::UnboundVariableError)
    end
  end

  describe 'let' do
    it 'basic let' do
      expect(eval_str('(let ((x 5)) x)')).to eq(5)
    end

    it 'let with multiple bindings' do
      expect(eval_str('(let ((x 2) (y 3)) (* x y))')).to eq(6)
    end

    it 'named let (loops)' do
      result = eval_str('(let loop ((i 0) (acc 0)) (if (= i 5) acc (loop (+ i 1) (+ acc i))))')
      expect(result).to eq(10)
    end
  end

  describe 'let*' do
    it 'bindings can reference previous' do
      expect(eval_str('(let* ((x 1) (y (+ x 1))) y)')).to eq(2)
    end
  end

  describe 'letrec' do
    it 'allows mutual recursion' do
      code = '(letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
                       (odd?  (lambda (n) (if (= n 0) #f (even? (- n 1))))))
               (even? 10))'
      expect(eval_str(code)).to eq(true)
    end
  end

  describe 'cond' do
    it 'matches first true clause' do
      expect(eval_str('(cond (#f 1) (#t 2) (else 3))')).to eq(2)
    end

    it 'uses else' do
      expect(eval_str('(cond (#f 1) (else 3))')).to eq(3)
    end

    it 'handles => syntax' do
      expect(eval_str('(cond (1 => (lambda (x) (* x 10))))')).to eq(10)
    end
  end

  describe 'case' do
    it 'matches datum' do
      expect(eval_str('(case 2 ((1) "one") ((2) "two") (else "other"))')).to eq('two')
    end

    it 'uses else' do
      expect(eval_str('(case 99 ((1) "one") (else "other"))')).to eq('other')
    end
  end

  describe 'and/or' do
    it 'and returns last true value' do
      expect(eval_str('(and 1 2 3)')).to eq(3)
    end

    it 'and short-circuits on false' do
      expect(eval_str('(and 1 #f 3)')).to eq(false)
    end

    it 'and with no args returns true' do
      expect(eval_str('(and)')).to eq(true)
    end

    it 'or returns first true value' do
      expect(eval_str('(or #f #f 3 4)')).to eq(3)
    end

    it 'or returns false when all false' do
      expect(eval_str('(or #f #f)')).to eq(false)
    end

    it 'or with no args returns false' do
      expect(eval_str('(or)')).to eq(false)
    end
  end

  describe 'quasiquote' do
    it 'basic quasiquote' do
      result = eval_str('`(1 2 3)')
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'unquote in quasiquote' do
      eval_str('(define x 42)', env)
      result = eval_str('`(a ,x c)', env)
      arr = result.to_a
      expect(arr[0].name).to eq('a')
      expect(arr[1]).to eq(42)
    end

    it 'unquote-splicing' do
      eval_str('(define lst \'(2 3))', env)
      result = eval_str('`(1 ,@lst 4)', env)
      expect(result.to_a).to eq([1, 2, 3, 4])
    end
  end

  describe 'do' do
    it 'basic do loop' do
      result = eval_str('(do ((i 0 (+ i 1)) (s 0 (+ s i))) ((= i 5) s))')
      expect(result).to eq(10)
    end
  end

  describe 'delay/force' do
    it 'creates promise' do
      result = eval_str('(delay 42)')
      expect(result).to be_a(Sucheme::SchemePromise)
    end

    it 'forces promise' do
      result = eval_str('(force (delay 42))')
      expect(result).to eq(42)
    end

    it 'memoizes promise' do
      eval_str('(define count 0)', env)
      eval_str('(define p (delay (begin (set! count (+ count 1)) count)))', env)
      eval_str('(force p)', env)
      eval_str('(force p)', env)
      expect(eval_str('count', env)).to eq(1)
    end
  end

  describe 'tail call optimization' do
    it 'handles deep recursion without stack overflow' do
      code = '(define (count-down n) (if (= n 0) "done" (count-down (- n 1))))'
      eval_str(code, env)
      expect(eval_str('(count-down 100000)', env)).to eq('done')
    end

    it 'tail calls in named let' do
      result = eval_str('(let loop ((n 100000) (acc 0)) (if (= n 0) acc (loop (- n 1) (+ acc 1))))')
      expect(result).to eq(100000)
    end
  end

  describe 'define-syntax / syntax-rules' do
    it 'defines and applies macro' do
      code = '(define-syntax my-if
               (syntax-rules ()
                 ((my-if test then else)
                  (cond (test then) (else else)))))
              (my-if #t 1 2)'
      expect(eval_str(code)).to eq(1)
    end

    it 'handles ellipsis' do
      code = '(define-syntax my-list
               (syntax-rules ()
                 ((my-list x ...) (list x ...))))
              (my-list 1 2 3)'
      result = eval_str(code)
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'handles nested patterns' do
      code = '(define-syntax swap!
               (syntax-rules ()
                 ((swap! a b)
                  (let ((tmp a))
                    (set! a b)
                    (set! b tmp)))))
              (define x 1)
              (define y 2)
              (swap! x y)
              (list x y)'
      result = eval_str(code)
      expect(result.to_a).to eq([2, 1])
    end

    it 'let-syntax body executes exactly once (no double evaluation)' do
      env2 = described_class.make_global_env
      eval_str('(define counter 0)', env2)
      eval_str('(let-syntax ((double (syntax-rules ()
                                       ((double x) (* x 2)))))
                  (set! counter (+ counter 1))
                  (double 5))', env2)
      expect(eval_str('counter', env2)).to eq(1)
    end
  end

  describe 'define-record-type' do
    it 'creates record type' do
      code = '(define-record-type <point>
                (make-point x y)
                point?
                (x point-x)
                (y point-y))
              (define p (make-point 3 4))
              (list (point? p) (point-x p) (point-y p))'
      result = eval_str(code)
      expect(result.to_a).to eq([true, 3, 4])
    end
  end

  describe 'values and call-with-values' do
    it 'single value' do
      expect(eval_str('(values 42)')).to eq(42)
    end

    it 'call-with-values' do
      result = eval_str('(call-with-values (lambda () (values 1 2)) +)')
      expect(result).to eq(3)
    end

    it 'let-values basic' do
      result = eval_str('(let-values (((a b) (values 1 2))) (+ a b))')
      expect(result).to eq(3)
    end

    it 'let-values body executes exactly once (no double evaluation)' do
      env2 = described_class.make_global_env
      eval_str('(define counter 0)', env2)
      eval_str('(let-values (((a) (values 10)))
                  (set! counter (+ counter 1))
                  a)', env2)
      expect(eval_str('counter', env2)).to eq(1)
    end

    it 'let*-values basic' do
      result = eval_str('(let*-values (((a b) (values 1 2)) ((c) (+ a b))) c)')
      expect(result).to eq(3)
    end
  end

  describe 'call/cc' do
    it 'basic escape continuation' do
      result = eval_str('(call/cc (lambda (k) (k 42) 100))')
      expect(result).to eq(42)
    end

    it 'non-local exit from list processing' do
      code = '(define result
                (call/cc
                  (lambda (exit)
                    (let loop ((lst \'(1 2 3 4 5)))
                      (if (null? lst) 0
                          (if (= (car lst) 3)
                              (exit (car lst))
                              (loop (cdr lst))))))))
              result'
      expect(eval_str(code)).to eq(3)
    end
  end

  describe 'internal defines' do
    it 'allows internal defines in body' do
      result = eval_str('(let ()
                           (define x 1)
                           (define y 2)
                           (+ x y))')
      expect(result).to eq(3)
    end
  end

  describe 'when/unless' do
    it 'when with true condition' do
      eval_str('(define x 0)', env)
      eval_str('(when #t (set! x 1))', env)
      expect(eval_str('x', env)).to eq(1)
    end

    it 'when with false condition' do
      eval_str('(define x 0)', env)
      eval_str('(when #f (set! x 1))', env)
      expect(eval_str('x', env)).to eq(0)
    end

    it 'unless with false condition' do
      eval_str('(define x 0)', env)
      eval_str('(unless #f (set! x 1))', env)
      expect(eval_str('x', env)).to eq(1)
    end
  end

  describe 'make_sandbox_env' do
    let(:sandbox) { described_class.make_sandbox_env }

    it 'allows normal arithmetic in sandbox' do
      expect(described_class.eval_source('(+ 1 2)', sandbox)).to eq(3)
    end

    it 'blocks open-input-file in sandbox' do
      expect { described_class.eval_source('(open-input-file "test.txt")', sandbox) }
        .to raise_error(Sucheme::EvalError, /open-input-file.*not available in sandbox/)
    end

    it 'blocks open-output-file in sandbox' do
      expect { described_class.eval_source('(open-output-file "test.txt")', sandbox) }
        .to raise_error(Sucheme::EvalError, /open-output-file.*not available in sandbox/)
    end

    it 'blocks load in sandbox' do
      expect { described_class.eval_source('(load "file.scm")', sandbox) }
        .to raise_error(Sucheme::EvalError, /load.*not available in sandbox/)
    end

    it 'blocks exit in sandbox' do
      expect { described_class.eval_source('(exit)', sandbox) }
        .to raise_error(Sucheme::EvalError, /exit.*not available in sandbox/)
    end

    it 'blocks call-with-input-file in sandbox' do
      expect { described_class.eval_source('(call-with-input-file "f" (lambda (p) #f))', sandbox) }
        .to raise_error(Sucheme::EvalError, /call-with-input-file.*not available in sandbox/)
    end

    it 'blocks call-with-output-file in sandbox' do
      expect { described_class.eval_source('(call-with-output-file "f" (lambda (p) #f))', sandbox) }
        .to raise_error(Sucheme::EvalError, /call-with-output-file.*not available in sandbox/)
    end

    it 'blocks with-input-from-file in sandbox' do
      expect { described_class.eval_source('(with-input-from-file "f" (lambda () #f))', sandbox) }
        .to raise_error(Sucheme::EvalError, /with-input-from-file.*not available in sandbox/)
    end

    it 'blocks with-output-to-file in sandbox' do
      expect { described_class.eval_source('(with-output-to-file "f" (lambda () #f))', sandbox) }
        .to raise_error(Sucheme::EvalError, /with-output-to-file.*not available in sandbox/)
    end
  end
end
