# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'benchmark'
require 'sucheme'

env = Sucheme::Evaluator.make_global_env

# Takeuchi function (竹内関数 / tarai)
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

# Sum via tail recursion
Sucheme::Evaluator.eval_source(<<~SCHEME, env)
  (define (sum-iter n acc)
    (if (= n 0)
        acc
        (sum-iter (- n 1) (+ acc n))))
SCHEME

BENCHMARKS = [
  { name: 'tak(12,6,0)      [Takeuchi/竹内関数]', code: '(tak 12 6 0)', expected: 1 },
  { name: 'fib(25)          [Fibonacci]', code: '(fib 25)', expected: 75025 },
  { name: 'ackermann(3,6)   [Ackermann]', code: '(ackermann 3 6)', expected: 509 },
  { name: 'sum-iter(100000) [tail recursion]', code: '(sum-iter 100000 0)', expected: 5_000_050_000 }
].freeze

puts "Sucheme Benchmark Suite"
puts "Ruby #{RUBY_VERSION} / #{RUBY_PLATFORM}"
puts "=" * 60
puts format("%-45s %12s %10s", "Benchmark", "Time (ms)", "i/s")
puts "-" * 60

results = []

BENCHMARKS.each do |bm|
  # Warmup
  3.times { Sucheme::Evaluator.eval_source(bm[:code], env) }

  # Measure
  n = 5
  elapsed = Benchmark.realtime do
    n.times { Sucheme::Evaluator.eval_source(bm[:code], env) }
  end

  ms = (elapsed / n * 1000).round(2)
  ips = (n / elapsed).round(2)
  result = Sucheme::Evaluator.eval_source(bm[:code], env)
  status = result == bm[:expected] ? "✓" : "✗(expected #{bm[:expected]}, got #{result})"

  puts format("%-45s %12.2f %10.2f  %s", bm[:name], ms, ips, status)
  results << { name: bm[:name], ms: ms, ips: ips }
end

puts "=" * 60

# Output GitHub Actions job summary if GITHUB_STEP_SUMMARY is set
summary_file = ENV['GITHUB_STEP_SUMMARY']
if summary_file && !summary_file.empty?
  File.open(summary_file, 'a') do |f|
    f.puts "## ⚡ Sucheme Benchmark Results"
    f.puts ""
    f.puts "Ruby #{RUBY_VERSION} / #{RUBY_PLATFORM}"
    f.puts ""
    f.puts "| Benchmark | Time (ms/call) | Throughput (i/s) |"
    f.puts "|-----------|----------------|------------------|"
    results.each do |r|
      f.puts "| #{r[:name]} | #{r[:ms]} | #{r[:ips]} |"
    end
    f.puts ""
  end
  puts "\nBenchmark results written to GitHub Actions job summary."
end
