# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'benchmark/ips'
require 'sucheme'

env = Sucheme::Evaluator.make_global_env

# Takeuchi function (tarai)
Sucheme::Evaluator.eval_source(<<~SCHEME, env)
  (define (tak x y z)
    (if (not (< y x))
        z
        (tak (tak (- x 1) y z)
             (tak (- y 1) z x)
             (tak (- z 1) x y))))
SCHEME

# Fibonacci
Sucheme::Evaluator.eval_source(<<~SCHEME, env)
  (define (fib n)
    (if (< n 2)
        n
        (+ (fib (- n 1)) (fib (- n 2)))))
SCHEME

# Ackermann
Sucheme::Evaluator.eval_source(<<~SCHEME, env)
  (define (ackermann m n)
    (cond ((= m 0) (+ n 1))
          ((= n 0) (ackermann (- m 1) 1))
          (else (ackermann (- m 1) (ackermann m (- n 1))))))
SCHEME

# Sum via recursion
Sucheme::Evaluator.eval_source(<<~SCHEME, env)
  (define (sum-iter n acc)
    (if (= n 0)
        acc
        (sum-iter (- n 1) (+ acc n))))
SCHEME

puts "Sucheme Benchmark Suite"
puts "=" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 1)

  x.report('fib(25)') do
    Sucheme::Evaluator.eval_source('(fib 25)', env)
  end

  x.report('tak(12,6,0)') do
    Sucheme::Evaluator.eval_source('(tak 12 6 0)', env)
  end

  x.report('ackermann(3,6)') do
    Sucheme::Evaluator.eval_source('(ackermann 3 6)', env)
  end

  x.report('sum-iter(100000)') do
    Sucheme::Evaluator.eval_source('(sum-iter 100000 0)', env)
  end

  x.compare!
end
