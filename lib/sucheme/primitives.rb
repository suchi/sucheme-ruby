# frozen_string_literal: true

require 'stringio'

module Sucheme
  module Primitives
    class << self
      def install(env)
        install_arithmetic(env)
        install_comparison(env)
        install_type_predicates(env)
        install_boolean(env)
        install_pairs_lists(env)
        install_strings(env)
        install_characters(env)
        install_vectors(env)
        install_io(env)
        install_control(env)
        install_equivalence(env)
        install_ports(env)
        install_misc(env)
      end

      private

      def prim(env, name, &block)
        env.define(name, SchemePrimitive.new(name, &block))
      end

      def install_arithmetic(env)
        prim(env, '+') do |*args|
          args.each { |a| check_number('+', a) }
          args.reduce(0, :+)
        end

        prim(env, '-') do |*args|
          raise ArityError, "'-' requires at least 1 argument" if args.empty?

          args.each { |a| check_number('-', a) }
          args.length == 1 ? -args[0] : args.reduce(:-)
        end

        prim(env, '*') do |*args|
          args.each { |a| check_number('*', a) }
          args.reduce(1, :*)
        end

        prim(env, '/') do |*args|
          raise ArityError, "'/' requires at least 1 argument" if args.empty?

          args.each { |a| check_number('/', a) }
          if args.length == 1
            Rational(1, 1) / args[0]
          else
            args[1..].each do |d|
              raise EvalError, "Division by zero" if d.zero?
            end
            # Use rational arithmetic to preserve exactness
            result = args[0]
            args[1..].each do |d|
              if result.is_a?(Float) || d.is_a?(Float)
                result = result.to_f / d.to_f
              else
                result = Rational(result, 1) / Rational(d, 1)
                result = result.numerator if result.denominator == 1
              end
            end
            result
          end
        end

        prim(env, 'quotient') do |a, b|
          check_integer('quotient', a)
          check_integer('quotient', b)
          raise EvalError, "Division by zero" if b.zero?

          (a.to_i.fdiv(b.to_i)).truncate
        end

        prim(env, 'remainder') do |a, b|
          check_integer('remainder', a)
          check_integer('remainder', b)
          raise EvalError, "Division by zero" if b.zero?

          a.to_i.remainder(b.to_i)
        end

        prim(env, 'modulo') do |a, b|
          check_integer('modulo', a)
          check_integer('modulo', b)
          raise EvalError, "Division by zero" if b.zero?

          a.to_i % b.to_i
        end

        prim(env, 'abs') do |a|
          check_number('abs', a)
          a.abs
        end

        prim(env, 'max') do |*args|
          raise ArityError, "'max' requires at least 1 argument" if args.empty?

          args.each { |a| check_number('max', a) }
          result = args.max
          # If any arg is inexact, result is inexact
          args.any? { |a| a.is_a?(Float) } ? result.to_f : result
        end

        prim(env, 'min') do |*args|
          raise ArityError, "'min' requires at least 1 argument" if args.empty?

          args.each { |a| check_number('min', a) }
          result = args.min
          args.any? { |a| a.is_a?(Float) } ? result.to_f : result
        end

        prim(env, 'expt') do |base, exp|
          check_number('expt', base)
          check_number('expt', exp)
          if exp.is_a?(Integer) && exp >= 0
            base**exp
          else
            base.to_f**exp.to_f
          end
        end

        prim(env, 'sqrt') do |a|
          check_number('sqrt', a)
          r = Math.sqrt(a.to_f)
          r == r.floor ? r.to_i : r
        end

        prim(env, 'floor') do |a|
          check_number('floor', a)
          a.is_a?(Float) ? a.floor.to_f : a.floor
        end

        prim(env, 'ceiling') do |a|
          check_number('ceiling', a)
          a.is_a?(Float) ? a.ceil.to_f : a.ceil
        end

        prim(env, 'truncate') do |a|
          check_number('truncate', a)
          a.is_a?(Float) ? a.truncate.to_f : a.truncate
        end

        prim(env, 'round') do |a|
          check_number('round', a)
          # R5RS: round to even (banker's rounding)
          result = a.round(half: :even)
          a.is_a?(Float) ? result.to_f : result
        end

        prim(env, 'gcd') do |*args|
          args.each { |a| check_integer('gcd', a) }
          result = args.map(&:abs).reduce(0) { |a, b| a.gcd(b) }
          result
        end

        prim(env, 'lcm') do |*args|
          args.each { |a| check_integer('lcm', a) }
          result = args.map(&:abs).reduce(1) { |a, b| a.lcm(b) }
          result
        end

        prim(env, 'numerator') do |a|
          check_number('numerator', a)
          case a
          when Integer then a
          when Rational then a.numerator
          when Float then a  # inexact
          else raise TypeError, "numerator: not a number: #{a}"
          end
        end

        prim(env, 'denominator') do |a|
          check_number('denominator', a)
          case a
          when Integer then 1
          when Rational then a.denominator
          when Float then 1.0  # inexact
          else raise TypeError, "denominator: not a number: #{a}"
          end
        end

        prim(env, 'exact->inexact') do |a|
          check_number('exact->inexact', a)
          a.to_f
        end

        prim(env, 'inexact->exact') do |a|
          check_number('inexact->exact', a)
          case a
          when Integer then a
          when Rational then a
          when Float
            r = a.rationalize
            r.denominator == 1 ? r.numerator : r
          end
        end

        prim(env, 'number->string') do |num, *rest|
          check_number('number->string', num)
          radix = rest.empty? ? 10 : rest[0].to_i
          case num
          when Integer then num.to_s(radix)
          when Rational then "#{num.numerator}/#{num.denominator}"
          when Float then num.to_s
          end
        end

        prim(env, 'string->number') do |str, *rest|
          raise TypeError, "string->number: not a string: #{str}" unless str.is_a?(String)

          radix = rest.empty? ? 10 : rest[0].to_i
          begin
            lexer = Lexer.new(str)
            tok = lexer.next_token
            if tok.type == TOKEN_NUMBER
              tok.value
            else
              false
            end
          rescue LexError
            false
          end
        end

        # Trigonometric / exponential
        %w[sin cos tan asin acos atan exp log].each do |fn|
          prim(env, fn) do |a, *rest|
            check_number(fn, a)
            if fn == 'atan' && rest.length == 1
              Math.atan2(a.to_f, rest[0].to_f)
            else
              Math.send(fn, a.to_f)
            end
          end
        end

        prim(env, 'exact') do |a|
          check_number('exact', a)
          case a
          when Integer then a
          when Rational then a
          when Float
            r = a.rationalize
            r.denominator == 1 ? r.numerator : r
          end
        end

        prim(env, 'inexact') do |a|
          check_number('inexact', a)
          a.to_f
        end

        prim(env, 'floor/') do |a, b|
          check_integer('floor/', a)
          check_integer('floor/', b)
          q = a.div(b)
          r = a - q * b
          SchemeValues.new([q, r])
        end

        prim(env, 'floor-quotient') do |a, b|
          check_integer('floor-quotient', a)
          check_integer('floor-quotient', b)
          a.div(b)
        end

        prim(env, 'floor-remainder') do |a, b|
          check_integer('floor-remainder', a)
          check_integer('floor-remainder', b)
          a % b
        end
      end

      def install_comparison(env)
        # Map Scheme comparison ops to Ruby methods
        op_map = { '=' => '==', '<' => '<', '>' => '>', '<=' => '<=', '>=' => '>=' }
        %w[= < > <= >=].each do |op|
          ruby_op = op_map[op]
          prim(env, op) do |*args|
            raise ArityError, "'#{op}' requires at least 2 arguments" if args.length < 2

            args.each { |a| check_number(op, a) }
            args.each_cons(2).all? { |a, b| a.send(ruby_op, b) }
          end
        end
      end

      def install_type_predicates(env)
        prim(env, 'pair?')      { |a| a.is_a?(SchemePair) }
        prim(env, 'null?')      { |a| a.is_a?(SchemeNull) }
        prim(env, 'list?') do |a|
          current = a
          seen = {}
          result = false
          done = false
          until done
            if current.is_a?(SchemeNull)
              result = true
              done = true
            elsif !current.is_a?(SchemePair) || seen[current.object_id]
              result = false
              done = true
            else
              seen[current.object_id] = true
              current = current.cdr
            end
          end
          result
        end
        prim(env, 'number?')    { |a| a.is_a?(Numeric) }
        prim(env, 'integer?')   { |a| a.is_a?(Integer) || (a.is_a?(Float) && a.finite? && a == a.floor) || (a.is_a?(Rational) && a.denominator == 1) }
        prim(env, 'real?')      { |a| a.is_a?(Numeric) }
        prim(env, 'rational?')  { |a| a.is_a?(Integer) || a.is_a?(Rational) || (a.is_a?(Float) && a.finite?) }
        prim(env, 'complex?')   { |a| a.is_a?(Numeric) }
        prim(env, 'exact?')     { |a| check_number('exact?', a); a.is_a?(Integer) || a.is_a?(Rational) }
        prim(env, 'inexact?')   { |a| check_number('inexact?', a); a.is_a?(Float) }
        prim(env, 'zero?')      { |a| check_number('zero?', a); a.zero? }
        prim(env, 'positive?')  { |a| check_number('positive?', a); a > 0 }
        prim(env, 'negative?')  { |a| check_number('negative?', a); a < 0 }
        prim(env, 'odd?')       { |a| check_integer('odd?', a); a.to_i.odd? }
        prim(env, 'even?')      { |a| check_integer('even?', a); a.to_i.even? }
        prim(env, 'boolean?')   { |a| a == true || a == false }
        prim(env, 'string?')    { |a| a.is_a?(String) }
        prim(env, 'symbol?')    { |a| a.is_a?(SchemeSymbol) }
        prim(env, 'char?')      { |a| a.is_a?(SchemeChar) }
        prim(env, 'vector?')    { |a| a.is_a?(SchemeVector) }
        prim(env, 'procedure?') { |a| a.is_a?(SchemeProcedure) || a.is_a?(SchemePrimitive) || a.is_a?(SchemeContinuation) }
        prim(env, 'port?')      { |a| a.is_a?(SchemePort) }
        prim(env, 'input-port?') { |a| a.is_a?(SchemePort) && a.input? }
        prim(env, 'output-port?') { |a| a.is_a?(SchemePort) && a.output? }
        prim(env, 'eof-object?') { |a| a.is_a?(SchemeEof) }
        prim(env, 'eof-object')  { SchemeEof::INSTANCE }
        prim(env, 'not')         { |a| a == false }
      end

      def install_boolean(env)
        prim(env, 'boolean=?') do |*args|
          raise ArityError, "boolean=? requires at least 2 args" if args.length < 2

          args.each { |a| raise TypeError, "boolean=?: not a boolean: #{a}" unless a == true || a == false }
          args.all? { |a| a == args[0] }
        end
      end

      def install_pairs_lists(env)
        prim(env, 'cons') do |a, b|
          SchemePair.new(a, b)
        end

        prim(env, 'car') do |a|
          raise TypeError, "car: not a pair: #{scheme_write(a)}" unless a.is_a?(SchemePair)

          a.car
        end

        prim(env, 'cdr') do |a|
          raise TypeError, "cdr: not a pair: #{scheme_write(a)}" unless a.is_a?(SchemePair)

          a.cdr
        end

        prim(env, 'set-car!') do |pair, val|
          raise TypeError, "set-car!: not a pair: #{scheme_write(pair)}" unless pair.is_a?(SchemePair)

          pair.car = val
          VOID
        end

        prim(env, 'set-cdr!') do |pair, val|
          raise TypeError, "set-cdr!: not a pair: #{scheme_write(pair)}" unless pair.is_a?(SchemePair)

          pair.cdr = val
          VOID
        end

        prim(env, 'list') do |*args|
          Sucheme.array_to_list(args)
        end

        prim(env, 'length') do |lst|
          count = 0
          current = lst
          while current.is_a?(SchemePair)
            count += 1
            current = current.cdr
          end
          raise TypeError, "length: not a proper list: #{scheme_write(lst)}" unless current.is_a?(SchemeNull)

          count
        end

        prim(env, 'append') do |*args|
          if args.empty?
            NULL
          elsif args.length == 1
            args[0]
          else
            result = args.last
            args[0..-2].reverse_each do |lst|
              current = lst
              items = []
              while current.is_a?(SchemePair)
                items << current.car
                current = current.cdr
              end
              raise TypeError, "append: not a proper list" unless current.is_a?(SchemeNull)

              items.reverse_each { |item| result = SchemePair.new(item, result) }
            end
            result
          end
        end

        prim(env, 'reverse') do |lst|
          result = NULL
          current = lst
          while current.is_a?(SchemePair)
            result = SchemePair.new(current.car, result)
            current = current.cdr
          end
          raise TypeError, "reverse: not a proper list: #{scheme_write(lst)}" unless current.is_a?(SchemeNull)

          result
        end

        prim(env, 'list-tail') do |lst, k|
          check_integer('list-tail', k)
          current = lst
          k.to_i.times do
            raise TypeError, "list-tail: list too short" unless current.is_a?(SchemePair)

            current = current.cdr
          end
          current
        end

        prim(env, 'list-ref') do |lst, k|
          check_integer('list-ref', k)
          current = lst
          k.to_i.times do
            raise TypeError, "list-ref: list too short" unless current.is_a?(SchemePair)

            current = current.cdr
          end
          raise TypeError, "list-ref: index out of bounds" unless current.is_a?(SchemePair)

          current.car
        end

        # cXXr combinations
        %w[aa ad da dd
           aaa aad ada add daa dad dda ddd
           aaaa aaad aada aadd adaa adad adda addd
           daaa daad dada dadd ddaa ddad ddda dddd].each do |combo|
          name = "c#{combo}r"
          prim(env, name) do |x|
            combo.reverse.each_char do |c|
              raise TypeError, "#{name}: not a pair: #{scheme_write(x)}" unless x.is_a?(SchemePair)

              x = c == 'a' ? x.car : x.cdr
            end
            x
          end
        end

        # Association list functions
        prim(env, 'assoc') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            pair = current.car
            if pair.is_a?(SchemePair) && scheme_equal?(pair.car, key)
              result = pair
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'assq') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            pair = current.car
            if pair.is_a?(SchemePair) && pair.car.equal?(key)
              result = pair
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'assv') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            pair = current.car
            if pair.is_a?(SchemePair) && scheme_eqv?(pair.car, key)
              result = pair
              break
            end
            current = current.cdr
          end
          result
        end

        # Member functions
        prim(env, 'member') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            if scheme_equal?(current.car, key)
              result = current
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'memq') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            if current.car.equal?(key)
              result = current
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'memv') do |key, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            if scheme_eqv?(current.car, key)
              result = current
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'list->vector') do |lst|
          items = []
          current = lst
          while current.is_a?(SchemePair)
            items << current.car
            current = current.cdr
          end
          SchemeVector.new(items)
        end

        prim(env, 'vector->list') do |vec|
          raise TypeError, "vector->list: not a vector: #{scheme_write(vec)}" unless vec.is_a?(SchemeVector)

          Sucheme.array_to_list(vec.data.dup)
        end

        prim(env, 'list-copy') do |lst|
          items = []
          current = lst
          while current.is_a?(SchemePair)
            items << current.car
            current = current.cdr
          end
          Sucheme.array_to_list(items)
        end

        prim(env, 'iota') do |count, *rest|
          start = rest[0] || 0
          step  = rest[1] || 1
          items = count.times.map { |i| start + i * step }
          Sucheme.array_to_list(items)
        end
      end

      def install_strings(env)
        prim(env, 'string') do |*args|
          args.each { |a| raise TypeError, "string: not a char: #{scheme_write(a)}" unless a.is_a?(SchemeChar) }
          args.map(&:char).join
        end

        prim(env, 'make-string') do |k, *rest|
          check_integer('make-string', k)
          ch = rest.empty? ? "\0" : (raise TypeError, "make-string: not a char" unless rest[0].is_a?(SchemeChar); rest[0].char)
          ch * k.to_i
        end

        prim(env, 'string-length') do |s|
          raise TypeError, "string-length: not a string: #{scheme_write(s)}" unless s.is_a?(String)

          s.length
        end

        prim(env, 'string-ref') do |s, k|
          raise TypeError, "string-ref: not a string" unless s.is_a?(String)

          check_integer('string-ref', k)
          raise EvalError, "string-ref: index out of bounds" if k < 0 || k >= s.length

          SchemeChar.new(s[k.to_i])
        end

        prim(env, 'string-set!') do |s, k, ch|
          raise TypeError, "string-set!: not a string" unless s.is_a?(String)

          check_integer('string-set!', k)
          raise TypeError, "string-set!: not a char" unless ch.is_a?(SchemeChar)

          s[k.to_i] = ch.char
          VOID
        end

        str_op_map = { '=' => '==', '<' => '<', '>' => '>', '<=' => '<=', '>=' => '>=' }
        %w[= < > <= >=].each do |op|
          ruby_op = str_op_map[op]
          prim(env, "string#{op}?") do |*args|
            raise ArityError, "string#{op}?: requires at least 2 args" if args.length < 2

            args.each { |a| raise TypeError, "string#{op}?: not a string: #{scheme_write(a)}" unless a.is_a?(String) }
            args.each_cons(2).all? { |a, b| a.send(ruby_op, b) }
          end

          prim(env, "string-ci#{op}?") do |*args|
            raise ArityError, "string-ci#{op}?: requires at least 2 args" if args.length < 2

            args.each { |a| raise TypeError, "string-ci#{op}?: not a string: #{scheme_write(a)}" unless a.is_a?(String) }
            args.each_cons(2).all? { |a, b| a.downcase.send(ruby_op, b.downcase) }
          end
        end

        prim(env, 'substring') do |s, start, *rest|
          raise TypeError, "substring: not a string" unless s.is_a?(String)

          check_integer('substring', start)
          finish = rest.empty? ? s.length : rest[0].to_i
          s[start.to_i...finish]
        end

        prim(env, 'string-append') do |*args|
          args.each { |a| raise TypeError, "string-append: not a string: #{scheme_write(a)}" unless a.is_a?(String) }
          args.join
        end

        prim(env, 'string->list') do |s, *rest|
          raise TypeError, "string->list: not a string" unless s.is_a?(String)

          start = rest[0] || 0
          finish = rest[1] || s.length
          chars = s[start.to_i...finish.to_i].chars.map { |c| SchemeChar.new(c) }
          Sucheme.array_to_list(chars)
        end

        prim(env, 'list->string') do |lst|
          chars = []
          current = lst
          while current.is_a?(SchemePair)
            raise TypeError, "list->string: not a char: #{scheme_write(current.car)}" unless current.car.is_a?(SchemeChar)

            chars << current.car.char
            current = current.cdr
          end
          chars.join
        end

        prim(env, 'string-copy') do |s, *_rest|
          raise TypeError, "string-copy: not a string" unless s.is_a?(String)

          s.dup
        end

        prim(env, 'string->symbol') do |s|
          raise TypeError, "string->symbol: not a string" unless s.is_a?(String)

          SchemeSymbol.intern(s)
        end

        prim(env, 'symbol->string') do |sym|
          raise TypeError, "symbol->string: not a symbol" unless sym.is_a?(SchemeSymbol)

          sym.name
        end

        prim(env, 'string-upcase') do |s|
          raise TypeError, "string-upcase: not a string" unless s.is_a?(String)

          s.upcase
        end

        prim(env, 'string-downcase') do |s|
          raise TypeError, "string-downcase: not a string" unless s.is_a?(String)

          s.downcase
        end

        prim(env, 'string-contains') do |s, sub|
          raise TypeError, "string-contains: not a string" unless s.is_a?(String)
          raise TypeError, "string-contains: not a string" unless sub.is_a?(String)

          idx = s.index(sub)
          idx.nil? ? false : idx
        end

        prim(env, 'string-split') do |s, sep|
          raise TypeError, "string-split: not a string" unless s.is_a?(String)
          raise TypeError, "string-split: not a string" unless sep.is_a?(String)

          Sucheme.array_to_list(s.split(sep))
        end

        prim(env, 'string-join') do |lst, *rest|
          sep = rest.empty? ? '' : rest[0]
          parts = []
          current = lst
          while current.is_a?(SchemePair)
            parts << current.car
            current = current.cdr
          end
          parts.join(sep)
        end
      end

      def install_characters(env)
        prim(env, 'char->integer') do |c|
          raise TypeError, "char->integer: not a char" unless c.is_a?(SchemeChar)

          c.char.ord
        end

        prim(env, 'integer->char') do |n|
          check_integer('integer->char', n)
          SchemeChar.new(n.to_i.chr(Encoding::UTF_8))
        end

        char_op_map = { '=' => '==', '<' => '<', '>' => '>', '<=' => '<=', '>=' => '>=' }
        %w[= < > <= >=].each do |op|
          ruby_op = char_op_map[op]
          prim(env, "char#{op}?") do |*args|
            raise ArityError, "char#{op}?: requires at least 2 args" if args.length < 2

            args.each { |a| raise TypeError, "char#{op}?: not a char" unless a.is_a?(SchemeChar) }
            args.each_cons(2).all? { |a, b| a.char.send(ruby_op, b.char) }
          end

          prim(env, "char-ci#{op}?") do |*args|
            raise ArityError, "char-ci#{op}?: requires at least 2 args" if args.length < 2

            args.each { |a| raise TypeError, "char-ci#{op}?: not a char" unless a.is_a?(SchemeChar) }
            args.each_cons(2).all? { |a, b| a.char.downcase.send(ruby_op, b.char.downcase) }
          end
        end

        prim(env, 'char-alphabetic?') { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); c.char.match?(/[a-zA-Z]/) }
        prim(env, 'char-numeric?')    { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); c.char.match?(/[0-9]/) }
        prim(env, 'char-whitespace?') { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); c.char.match?(/\s/) }
        prim(env, 'char-upper-case?') { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); c.char.match?(/[A-Z]/) }
        prim(env, 'char-lower-case?') { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); c.char.match?(/[a-z]/) }
        prim(env, 'char-upcase')      { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); SchemeChar.new(c.char.upcase) }
        prim(env, 'char-downcase')    { |c| raise TypeError, "not a char" unless c.is_a?(SchemeChar); SchemeChar.new(c.char.downcase) }
      end

      def install_vectors(env)
        prim(env, 'make-vector') do |k, *rest|
          check_integer('make-vector', k)
          fill = rest.empty? ? 0 : rest[0]
          SchemeVector.new(Array.new(k.to_i, fill))
        end

        prim(env, 'vector') do |*args|
          SchemeVector.new(args)
        end

        prim(env, 'vector-length') do |v|
          raise TypeError, "vector-length: not a vector" unless v.is_a?(SchemeVector)

          v.length
        end

        prim(env, 'vector-ref') do |v, k|
          raise TypeError, "vector-ref: not a vector" unless v.is_a?(SchemeVector)

          check_integer('vector-ref', k)
          raise EvalError, "vector-ref: index out of bounds: #{k}" if k < 0 || k >= v.length

          v[k.to_i]
        end

        prim(env, 'vector-set!') do |v, k, val|
          raise TypeError, "vector-set!: not a vector" unless v.is_a?(SchemeVector)

          check_integer('vector-set!', k)
          raise EvalError, "vector-set!: index out of bounds" if k < 0 || k >= v.length

          v[k.to_i] = val
          VOID
        end

        prim(env, 'vector-fill!') do |v, fill, *rest|
          raise TypeError, "vector-fill!: not a vector" unless v.is_a?(SchemeVector)

          start = rest[0] || 0
          finish = rest[1] || v.length
          (start.to_i...finish.to_i).each { |i| v[i] = fill }
          VOID
        end

        prim(env, 'vector-copy') do |v, *rest|
          raise TypeError, "vector-copy: not a vector" unless v.is_a?(SchemeVector)

          start = (rest[0] || 0).to_i
          finish = (rest[1] || v.length).to_i
          SchemeVector.new(v.data[start...finish].dup)
        end

        prim(env, 'vector-copy!') do |to, at, from, *rest|
          raise TypeError, "vector-copy!: not a vector" unless to.is_a?(SchemeVector)
          raise TypeError, "vector-copy!: not a vector" unless from.is_a?(SchemeVector)

          start = (rest[0] || 0).to_i
          finish = (rest[1] || from.length).to_i
          (start...finish).each_with_index do |fi, i|
            to[at.to_i + i] = from[fi]
          end
          VOID
        end

        prim(env, 'vector-append') do |*vecs|
          vecs.each { |v| raise TypeError, "vector-append: not a vector" unless v.is_a?(SchemeVector) }
          SchemeVector.new(vecs.flat_map { |v| v.data.dup })
        end

        prim(env, 'vector-map') do |proc, *vecs|
          raise ArityError, "vector-map: requires at least 2 args" if vecs.empty?

          vecs.each { |v| raise TypeError, "vector-map: not a vector" unless v.is_a?(SchemeVector) }
          len = vecs.map(&:length).min
          result = Array.new(len) do |i|
            args = vecs.map { |v| v[i] }
            Evaluator.apply(proc, args)
          end
          SchemeVector.new(result)
        end

        prim(env, 'vector-for-each') do |proc, *vecs|
          raise ArityError, "vector-for-each: requires at least 2 args" if vecs.empty?

          vecs.each { |v| raise TypeError, "vector-for-each: not a vector" unless v.is_a?(SchemeVector) }
          len = vecs.map(&:length).min
          len.times do |i|
            args = vecs.map { |v| v[i] }
            Evaluator.apply(proc, args)
          end
          VOID
        end

        prim(env, 'vector->string') do |v, *rest|
          raise TypeError, "vector->string: not a vector" unless v.is_a?(SchemeVector)

          start = (rest[0] || 0).to_i
          finish = (rest[1] || v.length).to_i
          v.data[start...finish].map do |c|
            raise TypeError, "vector->string: not a char: #{scheme_write(c)}" unless c.is_a?(SchemeChar)

            c.char
          end.join
        end

        prim(env, 'string->vector') do |s, *rest|
          raise TypeError, "string->vector: not a string" unless s.is_a?(String)

          start = (rest[0] || 0).to_i
          finish = (rest[1] || s.length).to_i
          SchemeVector.new(s[start...finish].chars.map { |c| SchemeChar.new(c) })
        end
      end

      def install_io(env)
        prim(env, 'display') do |obj, *rest|
          port = rest.empty? ? $stdout : port_io(rest[0])
          port.print(scheme_display(obj))
          VOID
        end

        prim(env, 'newline') do |*rest|
          port = rest.empty? ? $stdout : port_io(rest[0])
          port.puts
          VOID
        end

        prim(env, 'write') do |obj, *rest|
          port = rest.empty? ? $stdout : port_io(rest[0])
          port.print(scheme_write(obj))
          VOID
        end

        prim(env, 'write-char') do |ch, *rest|
          raise TypeError, "write-char: not a char" unless ch.is_a?(SchemeChar)

          port = rest.empty? ? $stdout : port_io(rest[0])
          port.print(ch.char)
          VOID
        end

        prim(env, 'read') do |*rest|
          port = rest.empty? ? $stdin : port_io(rest[0])
          input = port.gets
          return SchemeEof::INSTANCE if input.nil?

          exprs = Parser.parse(input.chomp)
          exprs.empty? ? SchemeEof::INSTANCE : exprs[0]
        end

        prim(env, 'read-char') do |*rest|
          port = rest.empty? ? $stdin : port_io(rest[0])
          ch = port.getc
          ch.nil? ? SchemeEof::INSTANCE : SchemeChar.new(ch)
        end

        prim(env, 'peek-char') do |*rest|
          port = rest.empty? ? $stdin : port_io(rest[0])
          ch = port.getc
          if ch.nil?
            SchemeEof::INSTANCE
          else
            port.ungetc(ch)
            SchemeChar.new(ch)
          end
        end

        prim(env, 'char-ready?') do |*_rest|
          true  # simplified
        end

        prim(env, 'read-line') do |*rest|
          port = rest.empty? ? $stdin : port_io(rest[0])
          line = port.gets
          line.nil? ? SchemeEof::INSTANCE : line.chomp
        end

        prim(env, 'open-input-file') do |path|
          raise TypeError, "open-input-file: not a string" unless path.is_a?(String)

          SchemePort.new(File.open(path, 'r'), :input)
        end

        prim(env, 'open-output-file') do |path|
          raise TypeError, "open-output-file: not a string" unless path.is_a?(String)

          SchemePort.new(File.open(path, 'w'), :output)
        end

        prim(env, 'close-input-port') do |port|
          raise TypeError, "close-input-port: not a port" unless port.is_a?(SchemePort)

          port.close
          VOID
        end

        prim(env, 'close-output-port') do |port|
          raise TypeError, "close-output-port: not a port" unless port.is_a?(SchemePort)

          port.close
          VOID
        end

        prim(env, 'close-port') do |port|
          raise TypeError, "close-port: not a port" unless port.is_a?(SchemePort)

          port.close
          VOID
        end

        prim(env, 'current-input-port')  { SchemePort.new($stdin, :input) }
        prim(env, 'current-output-port') { SchemePort.new($stdout, :output) }
        prim(env, 'current-error-port')  { SchemePort.new($stderr, :output) }

        prim(env, 'open-input-string') do |str|
          raise TypeError, "open-input-string: not a string" unless str.is_a?(String)

          SchemeStringPort.new(str, :input)
        end

        prim(env, 'open-output-string') do
          SchemeStringPort.new('', :output)
        end

        prim(env, 'get-output-string') do |port|
          raise TypeError, "get-output-string: not a string port" unless port.is_a?(SchemeStringPort)

          port.get_output_string
        end

        prim(env, 'with-input-from-file') do |path, thunk|
          raise TypeError, "with-input-from-file: not a string" unless path.is_a?(String)

          old_stdin = $stdin
          $stdin = File.open(path, 'r')
          begin
            Evaluator.apply(thunk, [])
          ensure
            $stdin.close
            $stdin = old_stdin
          end
        end

        prim(env, 'with-output-to-file') do |path, thunk|
          raise TypeError, "with-output-to-file: not a string" unless path.is_a?(String)

          old_stdout = $stdout
          $stdout = File.open(path, 'w')
          begin
            Evaluator.apply(thunk, [])
          ensure
            $stdout.close
            $stdout = old_stdout
          end
        end

        prim(env, 'call-with-input-file') do |path, proc|
          raise TypeError, "call-with-input-file: not a string" unless path.is_a?(String)

          port = SchemePort.new(File.open(path, 'r'), :input)
          begin
            Evaluator.apply(proc, [port])
          ensure
            port.close
          end
        end

        prim(env, 'call-with-output-file') do |path, proc|
          raise TypeError, "call-with-output-file: not a string" unless path.is_a?(String)

          port = SchemePort.new(File.open(path, 'w'), :output)
          begin
            Evaluator.apply(proc, [port])
          ensure
            port.close
          end
        end

        prim(env, 'call-with-port') do |port, proc|
          raise TypeError, "call-with-port: not a port" unless port.is_a?(SchemePort)

          begin
            Evaluator.apply(proc, [port])
          ensure
            port.close
          end
        end

        prim(env, 'with-input-from-string') do |str, thunk|
          raise TypeError, "not a string" unless str.is_a?(String)

          old = $stdin
          $stdin = StringIO.new(str)
          begin
            Evaluator.apply(thunk, [])
          ensure
            $stdin = old
          end
        end

        prim(env, 'flush-output-port') do |*rest|
          port = rest.empty? ? $stdout : port_io(rest[0])
          port.flush
          VOID
        end

        prim(env, 'flush-output') do |*rest|
          port = rest.empty? ? $stdout : port_io(rest[0])
          port.flush
          VOID
        end
      end

      def install_control(env)
        prim(env, 'apply') do |proc, *args|
          last = args.last
          rest = args[0..-2]
          tail_args = []
          current = last
          while current.is_a?(SchemePair)
            tail_args << current.car
            current = current.cdr
          end
          raise TypeError, "apply: last argument must be a list" unless current.is_a?(SchemeNull)

          Evaluator.apply(proc, rest + tail_args)
        end

        prim(env, 'map') do |proc, *lists|
          raise ArityError, "map: requires at least 2 args" if lists.empty?

          # Convert lists to arrays
          arrays = lists.map do |lst|
            arr = []
            current = lst
            while current.is_a?(SchemePair)
              arr << current.car
              current = current.cdr
            end
            arr
          end

          len = arrays.map(&:length).min
          result = (0...len).map { |i| Evaluator.apply(proc, arrays.map { |a| a[i] }) }
          Sucheme.array_to_list(result)
        end

        prim(env, 'for-each') do |proc, *lists|
          raise ArityError, "for-each: requires at least 2 args" if lists.empty?

          arrays = lists.map do |lst|
            arr = []
            current = lst
            while current.is_a?(SchemePair)
              arr << current.car
              current = current.cdr
            end
            arr
          end

          len = arrays.map(&:length).min
          (0...len).each { |i| Evaluator.apply(proc, arrays.map { |a| a[i] }) }
          VOID
        end

        prim(env, 'call-with-current-continuation') do |proc|
          Evaluator.call_with_cc(proc)
        end

        prim(env, 'call/cc') do |proc|
          Evaluator.call_with_cc(proc)
        end

        prim(env, 'values') do |*args|
          args.length == 1 ? args[0] : SchemeValues.new(args)
        end

        prim(env, 'call-with-values') do |producer, consumer|
          result = Evaluator.apply(producer, [])
          args = result.is_a?(SchemeValues) ? result.values : [result]
          Evaluator.apply(consumer, args)
        end

        prim(env, 'dynamic-wind') do |before, thunk, after|
          Evaluator.apply(before, [])
          begin
            result = Evaluator.apply(thunk, [])
          ensure
            Evaluator.apply(after, [])
          end
          result
        end

        prim(env, 'with-exception-handler') do |handler, thunk|
          Evaluator.apply(thunk, [])
        rescue SuchemeError => e
          Evaluator.apply(handler, [e.message])
        rescue => e
          Evaluator.apply(handler, [e.message])
        end

        prim(env, 'raise') do |obj|
          raise EvalError, scheme_write(obj)
        end

        prim(env, 'raise-continuable') do |obj|
          raise EvalError, scheme_write(obj)
        end

        prim(env, 'error') do |msg, *irritants|
          irritants_str = irritants.map { |i| scheme_write(i) }.join(' ')
          full_msg = irritants.empty? ? msg.to_s : "#{msg} #{irritants_str}"
          raise EvalError, full_msg
        end

        prim(env, 'error-message') do |e|
          e.is_a?(String) ? e : e.to_s
        end

        prim(env, 'condition/report-string') do |e|
          e.is_a?(String) ? e : e.to_s
        end

        prim(env, 'force') do |promise|
          raise TypeError, "force: not a promise" unless promise.is_a?(SchemePromise)

          unless promise.forced
            val = Evaluator.apply(promise.thunk, [])
            # Handle promise that returns a promise (R5RS)
            if val.is_a?(SchemePromise)
              promise.value = val.value
              promise.forced = val.forced
              promise.instance_variable_set(:@thunk, val.thunk) unless val.forced
            else
              promise.value = val
              promise.forced = true
            end
          end
          promise.value
        end

        prim(env, 'make-promise') do |val|
          if val.is_a?(SchemePromise)
            val
          else
            p = SchemePromise.new(nil)
            p.value = val
            p.forced = true
            p
          end
        end

        prim(env, 'promise?') { |a| a.is_a?(SchemePromise) }

        prim(env, 'exit') do |*rest|
          code = rest.empty? ? 0 : (rest[0] == false ? 1 : rest[0].to_i)
          exit(code)
        end

        prim(env, 'void') { VOID }
        prim(env, 'unspecified') { VOID }

        prim(env, 'make-parameter') do |val, *rest|
          converter = rest.empty? ? nil : rest[0]
          SchemeParameter.new(val, converter && ->(v) { Evaluator.apply(converter, [v]) })
        end

        prim(env, 'guard') { |*_| VOID }  # placeholder, handled in evaluator

        prim(env, 'filter') do |proc, lst|
          result = []
          current = lst
          while current.is_a?(SchemePair)
            val = Evaluator.apply(proc, [current.car])
            result << current.car unless val == false
            current = current.cdr
          end
          Sucheme.array_to_list(result)
        end

        prim(env, 'reduce') do |proc, init, lst|
          result = init
          current = lst
          while current.is_a?(SchemePair)
            result = Evaluator.apply(proc, [current.car, result])
            current = current.cdr
          end
          result
        end

        prim(env, 'fold-left') do |proc, init, lst|
          result = init
          current = lst
          while current.is_a?(SchemePair)
            result = Evaluator.apply(proc, [result, current.car])
            current = current.cdr
          end
          result
        end

        prim(env, 'fold-right') do |proc, init, lst|
          items = []
          current = lst
          while current.is_a?(SchemePair)
            items << current.car
            current = current.cdr
          end
          result = init
          items.reverse_each { |item| result = Evaluator.apply(proc, [item, result]) }
          result
        end

        prim(env, 'foldl') do |proc, init, lst|
          result = init
          current = lst
          while current.is_a?(SchemePair)
            result = Evaluator.apply(proc, [current.car, result])
            current = current.cdr
          end
          result
        end

        prim(env, 'foldr') do |proc, init, lst|
          items = []
          current = lst
          while current.is_a?(SchemePair)
            items << current.car
            current = current.cdr
          end
          result = init
          items.reverse_each { |item| result = Evaluator.apply(proc, [item, result]) }
          result
        end

        prim(env, 'any') do |proc, lst|
          current = lst
          result = false
          while current.is_a?(SchemePair)
            val = Evaluator.apply(proc, [current.car])
            if val != false
              result = val
              break
            end
            current = current.cdr
          end
          result
        end

        prim(env, 'every') do |proc, lst|
          current = lst
          result = true
          while current.is_a?(SchemePair)
            val = Evaluator.apply(proc, [current.car])
            if val == false
              result = false
              break
            end
            result = val
            current = current.cdr
          end
          result
        end

        prim(env, 'sort') do |lst, less_than|
          items = []
          current = lst
          while current.is_a?(SchemePair)
            items << current.car
            current = current.cdr
          end
          sorted = items.sort { |a, b| Evaluator.apply(less_than, [a, b]) == false ? 1 : -1 }
          Sucheme.array_to_list(sorted)
        end

        prim(env, 'string-for-each') do |proc, str, *rest|
          raise TypeError, "string-for-each: not a string" unless str.is_a?(String)

          str.each_char { |c| Evaluator.apply(proc, [SchemeChar.new(c)]) }
          VOID
        end

        prim(env, 'string-map') do |proc, str, *rest|
          raise TypeError, "string-map: not a string" unless str.is_a?(String)

          result = str.each_char.map { |c| Evaluator.apply(proc, [SchemeChar.new(c)]) }
          result.map { |c| c.is_a?(SchemeChar) ? c.char : c.to_s }.join
        end

        prim(env, 'char-foldcase') do |c|
          raise TypeError, "char-foldcase: not a char" unless c.is_a?(SchemeChar)

          SchemeChar.new(c.char.downcase)
        end

        prim(env, 'string-foldcase') do |s|
          raise TypeError, "string-foldcase: not a string" unless s.is_a?(String)

          s.downcase
        end
      end

      def install_equivalence(env)
        prim(env, 'eq?') do |a, b|
          # eq? - pointer equality
          case a
          when SchemeNull  then b.is_a?(SchemeNull)
          when SchemeSymbol then b.is_a?(SchemeSymbol) && a.name == b.name
          when true, false  then a == b
          when Integer      then a == b
          else a.equal?(b)
          end
        end

        prim(env, 'eqv?') do |a, b|
          scheme_eqv?(a, b)
        end

        prim(env, 'equal?') do |a, b|
          scheme_equal?(a, b)
        end
      end

      def install_ports(env)
        prim(env, 'make-string-input-port') do |str|
          raise TypeError, "not a string" unless str.is_a?(String)

          SchemeStringPort.new(str, :input)
        end

        prim(env, 'make-string-output-port') do
          SchemeStringPort.new('', :output)
        end

        prim(env, 'with-output-to-string') do |thunk|
          old_stdout = $stdout
          sio = StringIO.new
          $stdout = sio
          begin
            Evaluator.apply(thunk, [])
          ensure
            $stdout = old_stdout
          end
          sio.string
        end

        prim(env, 'with-input-from-port') do |port, thunk|
          raise TypeError, "not a port" unless port.is_a?(SchemePort)

          old = $stdin
          $stdin = port.io
          begin
            Evaluator.apply(thunk, [])
          ensure
            $stdin = old
          end
        end
      end

      def install_misc(env)
        prim(env, 'gensym') do
          @gensym_counter = (@gensym_counter || 0) + 1
          SchemeSymbol.intern("g#{@gensym_counter}")
        end

        prim(env, 'load') do |path|
          raise TypeError, "load: not a string" unless path.is_a?(String)

          source = File.read(path)
          exprs = Parser.parse(source, filename: path)
          env_ref = Evaluator.instance_variable_get(:@global_env)
          result = VOID
          exprs.each { |expr| result = Evaluator.eval_expr(expr, env_ref) }
          result
        end

        prim(env, 'interaction-environment') do
          # Return a representation; actual use requires evaluator access
          SchemeSymbol.intern('interaction-environment')
        end

        prim(env, 'scheme-report-environment') do |_version|
          SchemeSymbol.intern('scheme-report-environment')
        end

        prim(env, 'null-environment') do |_version|
          SchemeSymbol.intern('null-environment')
        end

        prim(env, 'eval') do |expr, _env_spec|
          Evaluator.eval_expr(expr, Evaluator.global_env)
        end

        prim(env, 'procedure-arity') do |proc|
          case proc
          when SchemeProcedure
            proc.params.length
          when SchemePrimitive
            -1
          else
            -1
          end
        end

        prim(env, 'number?') { |a| a.is_a?(Numeric) }
        prim(env, 'char->integer') do |c|
          raise TypeError, "char->integer: not a char" unless c.is_a?(SchemeChar)
          c.char.ord
        end

        prim(env, 'error-object?') { |a| a.is_a?(String) }
        prim(env, 'error-object-message') { |a| a.is_a?(String) ? a : a.to_s }
        prim(env, 'error-object-irritants') { |_a| NULL }

        prim(env, 'boolean->string') do |b|
          b == true ? '#t' : '#f'
        end

        prim(env, 'write-string') do |str, *rest|
          raise TypeError, "write-string: not a string" unless str.is_a?(String)

          port = rest.empty? ? $stdout : port_io(rest[0])
          port.print(str)
          VOID
        end

        prim(env, 'print') do |obj|
          puts scheme_display(obj)
          VOID
        end

        prim(env, 'pp') do |obj|
          puts scheme_write(obj)
          VOID
        end

        prim(env, 'format') do |*args|
          # Simple format: (format dest fmt ...)
          # dest can be #t (stdout), #f (return string), or a port
          if args[0].is_a?(String)
            # (format fmt args...)
            fmt = args[0]
            fmt_args = args[1..]
          elsif args[0] == true
            fmt = args[1].to_s
            fmt_args = args[2..]
          elsif args[0] == false
            fmt = args[1].to_s
            fmt_args = args[2..]
          else
            fmt = args[1].to_s
            fmt_args = args[2..]
          end

          result = +''
          idx = 0
          i = 0
          while i < fmt.length
            if fmt[i] == '~' && i + 1 < fmt.length
              case fmt[i + 1]
              when 'a', 'A'
                result << scheme_display(fmt_args[idx] || '')
                idx += 1
              when 's', 'S'
                result << scheme_write(fmt_args[idx] || '')
                idx += 1
              when '%'
                result << "\n"
              when '~'
                result << '~'
              when 'b', 'B'
                result << (fmt_args[idx] || 0).to_i.to_s(2)
                idx += 1
              when 'd', 'D'
                result << scheme_display(fmt_args[idx] || '')
                idx += 1
              else
                result << "~#{fmt[i + 1]}"
              end
              i += 2
            else
              result << fmt[i]
              i += 1
            end
          end

          if args[0] == false
            result
          else
            out = if args[0].is_a?(SchemePort)
                    args[0].io
                  else
                    $stdout
                  end
            out.print(result)
            VOID
          end
        end

        prim(env, 'with-exception-handler') do |handler, thunk|
          begin
            Evaluator.apply(thunk, [])
          rescue SuchemeError => e
            Evaluator.apply(handler, [e.message])
          rescue => e
            Evaluator.apply(handler, [e.message])
          end
        end

        prim(env, 'guard-handler') { |*_| VOID }

        prim(env, 'runtime') { Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i }
        prim(env, 'current-time') { Time.now.to_f }
      end

      # Helper methods
      def check_number(name, val)
        raise TypeError, "#{name}: not a number: #{scheme_write(val)}" unless val.is_a?(Numeric)
      end

      def check_integer(name, val)
        raise TypeError, "#{name}: not an integer: #{scheme_write(val)}" unless val.is_a?(Integer) || (val.is_a?(Rational) && val.denominator == 1) || (val.is_a?(Float) && val.finite? && val == val.floor)
      end

      def scheme_display(obj)
        case obj
        when String      then obj
        when SchemeNull  then '()'
        when SchemeChar  then obj.char
        when SchemeVoid  then ''
        when true        then '#t'
        when false       then '#f'
        else obj.to_s
        end
      end

      def scheme_write(obj)
        case obj
        when String
          "\"#{obj.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\t", '\\t').gsub("\r", '\\r')}\""
        when SchemeChar
          obj.write_repr
        when SchemeNull  then '()'
        when SchemeVoid  then ''
        when true        then '#t'
        when false       then '#f'
        else obj.to_s
        end
      end

      def scheme_eqv?(a, b)
        case a
        when SchemeNull    then b.is_a?(SchemeNull)
        when SchemeSymbol  then b.is_a?(SchemeSymbol) && a.name == b.name
        when SchemeChar    then b.is_a?(SchemeChar) && a.char == b.char
        when true, false   then a == b
        when Integer, Float, Rational then a == b && a.class == b.class
        else a.equal?(b)
        end
      end

      def scheme_equal?(a, b)
        return true if a.equal?(b)

        case a
        when SchemePair
          b.is_a?(SchemePair) && scheme_equal?(a.car, b.car) && scheme_equal?(a.cdr, b.cdr)
        when SchemeVector
          b.is_a?(SchemeVector) && a.length == b.length &&
            a.data.zip(b.data).all? { |x, y| scheme_equal?(x, y) }
        when String
          b.is_a?(String) && a == b
        else
          scheme_eqv?(a, b)
        end
      end

      def port_io(port)
        return port if port.is_a?(IO) || port.is_a?(StringIO)

        raise TypeError, "not a port: #{scheme_write(port)}" unless port.is_a?(SchemePort)

        port.io
      end
    end
  end
end
