# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Primitives' do
  let(:env) { Sucheme::Evaluator.make_global_env }

  def eval_str(source)
    Sucheme::Evaluator.eval_source(source, env)
  end

  describe 'arithmetic' do
    it '+ with no args returns 0' do
      expect(eval_str('(+)')).to eq(0)
    end

    it '+ with args' do
      expect(eval_str('(+ 1 2 3)')).to eq(6)
    end

    it '- unary negation' do
      expect(eval_str('(- 5)')).to eq(-5)
    end

    it '- subtraction' do
      expect(eval_str('(- 10 3 2)')).to eq(5)
    end

    it '* with no args returns 1' do
      expect(eval_str('(*)')).to eq(1)
    end

    it '* multiplication' do
      expect(eval_str('(* 2 3 4)')).to eq(24)
    end

    it '/ division' do
      result = eval_str('(/ 10 2)')
      expect(result).to eq(5)
    end

    it '/ returns rational for inexact division' do
      result = eval_str('(/ 1 3)')
      expect(result).to eq(Rational(1, 3))
    end

    it 'quotient' do
      expect(eval_str('(quotient 10 3)')).to eq(3)
      expect(eval_str('(quotient -10 3)')).to eq(-3)
    end

    it 'remainder' do
      expect(eval_str('(remainder 10 3)')).to eq(1)
      expect(eval_str('(remainder -10 3)')).to eq(-1)
    end

    it 'modulo' do
      expect(eval_str('(modulo 10 3)')).to eq(1)
      expect(eval_str('(modulo -10 3)')).to eq(2)
    end

    it 'abs' do
      expect(eval_str('(abs -5)')).to eq(5)
      expect(eval_str('(abs 5)')).to eq(5)
    end

    it 'max' do
      expect(eval_str('(max 1 2 3)')).to eq(3)
    end

    it 'min' do
      expect(eval_str('(min 1 2 3)')).to eq(1)
    end

    it 'expt' do
      expect(eval_str('(expt 2 10)')).to eq(1024)
    end

    it 'sqrt' do
      expect(eval_str('(sqrt 4)')).to eq(2)
    end

    it 'floor' do
      expect(eval_str('(floor 3.7)')).to eq(3.0)
    end

    it 'ceiling' do
      expect(eval_str('(ceiling 3.2)')).to eq(4.0)
    end

    it 'truncate' do
      expect(eval_str('(truncate 3.7)')).to eq(3.0)
    end

    it 'round' do
      expect(eval_str('(round 3.5)')).to eq(4.0)
      expect(eval_str('(round 4.5)')).to eq(4.0)  # banker's rounding
    end

    it 'gcd' do
      expect(eval_str('(gcd 12 8)')).to eq(4)
    end

    it 'lcm' do
      expect(eval_str('(lcm 4 6)')).to eq(12)
    end

    it 'exact->inexact' do
      expect(eval_str('(exact->inexact 1/2)')).to eq(0.5)
    end

    it 'inexact->exact' do
      expect(eval_str('(inexact->exact 0.5)')).to eq(Rational(1, 2))
    end
  end

  describe 'comparison' do
    it '= compares numbers' do
      expect(eval_str('(= 1 1)')).to eq(true)
      expect(eval_str('(= 1 2)')).to eq(false)
    end

    it '< less than' do
      expect(eval_str('(< 1 2 3)')).to eq(true)
      expect(eval_str('(< 1 3 2)')).to eq(false)
    end

    it '> greater than' do
      expect(eval_str('(> 3 2 1)')).to eq(true)
    end

    it '<= less than or equal' do
      expect(eval_str('(<= 1 1 2)')).to eq(true)
    end

    it '>= greater than or equal' do
      expect(eval_str('(>= 3 3 2)')).to eq(true)
    end
  end

  describe 'type predicates' do
    it 'pair?' do
      expect(eval_str("(pair? '(1 2))")).to eq(true)
      expect(eval_str('(pair? 42)')).to eq(false)
    end

    it 'null?' do
      expect(eval_str("(null? '())")).to eq(true)
      expect(eval_str("(null? '(1))")).to eq(false)
    end

    it 'list?' do
      expect(eval_str("(list? '(1 2 3))")).to eq(true)
      expect(eval_str("(list? '())")).to eq(true)
      expect(eval_str('(list? 42)')).to eq(false)
    end

    it 'number?' do
      expect(eval_str('(number? 42)')).to eq(true)
      expect(eval_str('(number? "42")')).to eq(false)
    end

    it 'integer?' do
      expect(eval_str('(integer? 42)')).to eq(true)
      expect(eval_str('(integer? 3.0)')).to eq(true)
      expect(eval_str('(integer? 3.5)')).to eq(false)
    end

    it 'boolean?' do
      expect(eval_str('(boolean? #t)')).to eq(true)
      expect(eval_str('(boolean? 1)')).to eq(false)
    end

    it 'string?' do
      expect(eval_str('(string? "hello")')).to eq(true)
      expect(eval_str('(string? 42)')).to eq(false)
    end

    it 'symbol?' do
      expect(eval_str("(symbol? 'foo)")).to eq(true)
      expect(eval_str('(symbol? "foo")')).to eq(false)
    end

    it 'char?' do
      expect(eval_str('(char? #\a)')).to eq(true)
      expect(eval_str('(char? "a")')).to eq(false)
    end

    it 'vector?' do
      expect(eval_str('(vector? #(1 2 3))')).to eq(true)
      expect(eval_str("(vector? '(1 2 3))")).to eq(false)
    end

    it 'procedure?' do
      expect(eval_str('(procedure? car)')).to eq(true)
      expect(eval_str('(procedure? (lambda (x) x))')).to eq(true)
      expect(eval_str('(procedure? 42)')).to eq(false)
    end

    it 'zero?, positive?, negative?' do
      expect(eval_str('(zero? 0)')).to eq(true)
      expect(eval_str('(positive? 1)')).to eq(true)
      expect(eval_str('(negative? -1)')).to eq(true)
    end

    it 'odd?, even?' do
      expect(eval_str('(odd? 3)')).to eq(true)
      expect(eval_str('(even? 4)')).to eq(true)
    end

    it 'exact?, inexact?' do
      expect(eval_str('(exact? 42)')).to eq(true)
      expect(eval_str('(inexact? 3.14)')).to eq(true)
    end
  end

  describe 'pairs and lists' do
    it 'cons creates a pair' do
      result = eval_str('(cons 1 2)')
      expect(result).to be_a(Sucheme::SchemePair)
      expect(result.car).to eq(1)
      expect(result.cdr).to eq(2)
    end

    it 'car' do
      expect(eval_str("(car '(1 2 3))")).to eq(1)
    end

    it 'cdr' do
      result = eval_str("(cdr '(1 2 3))")
      expect(result.car).to eq(2)
    end

    it 'list' do
      result = eval_str('(list 1 2 3)')
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'length' do
      expect(eval_str("(length '(1 2 3))")).to eq(3)
      expect(eval_str("(length '())")).to eq(0)
    end

    it 'append' do
      result = eval_str("(append '(1 2) '(3 4))")
      expect(result.to_a).to eq([1, 2, 3, 4])
    end

    it 'reverse' do
      result = eval_str("(reverse '(1 2 3))")
      expect(result.to_a).to eq([3, 2, 1])
    end

    it 'list-ref' do
      expect(eval_str("(list-ref '(a b c d) 2)")).to eq(Sucheme::SchemeSymbol.intern('c'))
    end

    it 'list-tail' do
      result = eval_str("(list-tail '(a b c d) 2)")
      expect(result.car.name).to eq('c')
    end

    it 'assoc' do
      result = eval_str("(assoc 'b '((a 1) (b 2) (c 3)))")
      expect(result.car.name).to eq('b')
    end

    it 'member' do
      result = eval_str("(member 3 '(1 2 3 4 5))")
      expect(result.car).to eq(3)
    end

    it 'set-car!' do
      eval_str("(define p '(1 2 3))")
      eval_str('(set-car! p 99)')
      expect(eval_str('(car p)')).to eq(99)
    end

    it 'cadr (caar, etc.)' do
      expect(eval_str("(cadr '(1 2 3))")).to eq(2)
      expect(eval_str("(caddr '(1 2 3))")).to eq(3)
    end
  end

  describe 'strings' do
    it 'string-length' do
      expect(eval_str('(string-length "hello")')).to eq(5)
    end

    it 'string-ref' do
      result = eval_str('(string-ref "hello" 1)')
      expect(result).to be_a(Sucheme::SchemeChar)
      expect(result.char).to eq('e')
    end

    it 'substring' do
      expect(eval_str('(substring "hello" 1 3)')).to eq('el')
    end

    it 'string-append' do
      expect(eval_str('(string-append "foo" "bar")')).to eq('foobar')
    end

    it 'string->list' do
      result = eval_str('(string->list "abc")')
      expect(result.to_a.map(&:char)).to eq(['a', 'b', 'c'])
    end

    it 'list->string' do
      result = eval_str("(list->string (list #\\a #\\b #\\c))")
      expect(result).to eq('abc')
    end

    it 'string->symbol' do
      result = eval_str('(string->symbol "foo")')
      expect(result.name).to eq('foo')
    end

    it 'symbol->string' do
      expect(eval_str("(symbol->string 'foo)")).to eq('foo')
    end

    it 'string comparisons' do
      expect(eval_str('(string=? "abc" "abc")')).to eq(true)
      expect(eval_str('(string<? "abc" "abd")')).to eq(true)
    end

    it 'string-upcase/downcase' do
      expect(eval_str('(string-upcase "hello")')).to eq('HELLO')
      expect(eval_str('(string-downcase "HELLO")')).to eq('hello')
    end

    it 'number->string' do
      expect(eval_str('(number->string 42)')).to eq('42')
      expect(eval_str('(number->string 255 16)')).to eq('ff')
    end

    it 'string->number' do
      expect(eval_str('(string->number "42")')).to eq(42)
      expect(eval_str('(string->number "abc")')).to eq(false)
      # radix support
      expect(eval_str('(string->number "ff" 16)')).to eq(255)
      expect(eval_str('(string->number "FF" 16)')).to eq(255)
      expect(eval_str('(string->number "11111111" 2)')).to eq(255)
      expect(eval_str('(string->number "377" 8)')).to eq(255)
      expect(eval_str('(string->number "zz" 16)')).to eq(false)
    end

    it 'make-string' do
      expect(eval_str('(make-string 5 #\x)')).to eq('xxxxx')
    end

    it 'string with chars' do
      expect(eval_str("(string #\\a #\\b #\\c)")).to eq('abc')
    end
  end

  describe 'characters' do
    it 'char->integer' do
      expect(eval_str('(char->integer #\A)')).to eq(65)
    end

    it 'integer->char' do
      result = eval_str('(integer->char 65)')
      expect(result.char).to eq('A')
    end

    it 'char=?, char<?, etc.' do
      expect(eval_str('(char=? #\a #\a)')).to eq(true)
      expect(eval_str('(char<? #\a #\b)')).to eq(true)
    end

    it 'char-alphabetic?' do
      expect(eval_str('(char-alphabetic? #\a)')).to eq(true)
      expect(eval_str('(char-alphabetic? #\1)')).to eq(false)
    end

    it 'char-upcase/downcase' do
      result = eval_str('(char-upcase #\a)')
      expect(result.char).to eq('A')
    end
  end

  describe 'vectors' do
    it 'make-vector' do
      result = eval_str('(make-vector 3 0)')
      expect(result.length).to eq(3)
      expect(result[0]).to eq(0)
    end

    it 'vector' do
      result = eval_str('(vector 1 2 3)')
      expect(result[0]).to eq(1)
    end

    it 'vector-ref' do
      expect(eval_str('(vector-ref #(10 20 30) 1)')).to eq(20)
    end

    it 'vector-set!' do
      eval_str('(define v (vector 1 2 3))')
      eval_str('(vector-set! v 1 99)')
      expect(eval_str('(vector-ref v 1)')).to eq(99)
    end

    it 'vector-length' do
      expect(eval_str('(vector-length #(1 2 3))')).to eq(3)
    end

    it 'vector->list' do
      result = eval_str('(vector->list #(1 2 3))')
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'list->vector' do
      result = eval_str("(list->vector '(1 2 3))")
      expect(result[0]).to eq(1)
    end
  end

  describe 'control' do
    it 'apply' do
      expect(eval_str("(apply + '(1 2 3))")).to eq(6)
    end

    it 'apply with extra args' do
      expect(eval_str("(apply + 1 2 '(3 4))")).to eq(10)
    end

    it 'map' do
      result = eval_str("(map (lambda (x) (* x x)) '(1 2 3 4 5))")
      expect(result.to_a).to eq([1, 4, 9, 16, 25])
    end

    it 'for-each' do
      eval_str('(define sum 0)')
      eval_str("(for-each (lambda (x) (set! sum (+ sum x))) '(1 2 3 4 5))")
      expect(eval_str('sum')).to eq(15)
    end

    it 'not' do
      expect(eval_str('(not #f)')).to eq(true)
      expect(eval_str('(not 42)')).to eq(false)
    end

    it 'fold-left argument order is (acc, item)' do
      # (fold-left f init '(1 2 3)) = (f (f (f init 1) 2) 3)
      result = eval_str("(fold-left (lambda (acc x) (cons x acc)) '() '(1 2 3))")
      expect(result.to_a).to eq([3, 2, 1])
    end

    it 'foldl argument order is (acc, item) same as fold-left' do
      result = eval_str("(foldl (lambda (acc x) (cons x acc)) '() '(1 2 3))")
      expect(result.to_a).to eq([3, 2, 1])
    end

    it 'fold-right argument order is (item, acc)' do
      # (fold-right f init '(1 2 3)) = (f 1 (f 2 (f 3 init)))
      result = eval_str("(fold-right cons '() '(1 2 3))")
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'foldr argument order is (item, acc) same as fold-right' do
      result = eval_str("(foldr cons '() '(1 2 3))")
      expect(result.to_a).to eq([1, 2, 3])
    end

    it 'fold-left and foldl compute same sum' do
      expect(eval_str("(fold-left + 0 '(1 2 3 4 5))")).to eq(15)
      expect(eval_str("(foldl + 0 '(1 2 3 4 5))")).to eq(15)
    end
  end

  describe 'equivalence' do
    it 'eq? for symbols' do
      expect(eval_str("(eq? 'foo 'foo)")).to eq(true)
      expect(eval_str("(eq? 'foo 'bar)")).to eq(false)
    end

    it 'eqv? for numbers' do
      expect(eval_str('(eqv? 42 42)')).to eq(true)
      expect(eval_str('(eqv? 42 42.0)')).to eq(false)
    end

    it 'equal? for lists' do
      expect(eval_str("(equal? '(1 2 3) '(1 2 3))")).to eq(true)
      expect(eval_str("(equal? '(1 2 3) '(1 2 4))")).to eq(false)
    end

    it 'equal? for strings' do
      expect(eval_str('(equal? "abc" "abc")')).to eq(true)
    end

    it 'equal? for vectors' do
      expect(eval_str('(equal? #(1 2 3) #(1 2 3))')).to eq(true)
    end
  end
end
