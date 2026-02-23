# frozen_string_literal: true

module Sucheme
  module Evaluator
    class << self
      attr_reader :global_env

      def make_global_env
        @global_env = Environment.make_global
        load_scheme_stdlib(@global_env)
        @global_env
      end

      def eval_source(source, env = nil, filename: '<string>')
        env ||= global_env || make_global_env
        exprs = Parser.parse(source, filename: filename)
        result = VOID
        exprs.each { |expr| result = eval_expr(expr, env) }
        result
      end

      def eval_expr(expr, env)
        loop do
          case expr
          when SchemeNull, Integer, Float, Rational, String, SchemeChar, SchemeVector, TrueClass, FalseClass
            return expr

          when SchemeVoid, SchemeEof, SchemePromise, SchemePrimitive, SchemeProcedure, SchemeMacro, SchemePort
            return expr

          when SchemeSymbol
            return env.lookup(expr)

          when SchemePair
            head = expr.car

            # Check for special forms
            if head.is_a?(SchemeSymbol)
              case head.name
              when 'quote'
                return expr.cdr.car

              when 'if'
                cond = eval_expr(expr.cdr.car, env)
                if cond != false
                  # True branch
                  expr = expr.cdr.cdr.car
                  next
                elsif expr.cdr.cdr.cdr.is_a?(SchemePair)
                  # False branch
                  expr = expr.cdr.cdr.cdr.car
                  next
                else
                  return VOID
                end

              when 'cond'
                result = eval_cond(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'and'
                clauses = expr.cdr
                return true if clauses.is_a?(SchemeNull)

                current = clauses
                while current.is_a?(SchemePair)
                  if current.cdr.is_a?(SchemeNull)
                    # Last expr - tail position
                    expr = current.car
                    break
                  end
                  result = eval_expr(current.car, env)
                  return false if result == false

                  current = current.cdr
                end
                next  # continue outer loop with updated expr

              when 'or'
                clauses = expr.cdr
                return false if clauses.is_a?(SchemeNull)

                current = clauses
                found_tail = false
                while current.is_a?(SchemePair)
                  if current.cdr.is_a?(SchemeNull)
                    expr = current.car
                    found_tail = true
                    break
                  end
                  result = eval_expr(current.car, env)
                  return result if result != false

                  current = current.cdr
                end
                next if found_tail  # continue outer loop
                return false

              when 'when'
                cond = eval_expr(expr.cdr.car, env)
                if cond != false
                  body = expr.cdr.cdr
                  current = body
                  while current.is_a?(SchemePair)
                    if current.cdr.is_a?(SchemeNull)
                      expr = current.car
                      break
                    end
                    eval_expr(current.car, env)
                    current = current.cdr
                  end
                  next  # tail call in last body expr
                end
                return VOID

              when 'unless'
                cond = eval_expr(expr.cdr.car, env)
                if cond == false
                  body = expr.cdr.cdr
                  current = body
                  while current.is_a?(SchemePair)
                    if current.cdr.is_a?(SchemeNull)
                      expr = current.car
                      break
                    end
                    eval_expr(current.car, env)
                    current = current.cdr
                  end
                  next
                end
                return VOID

              when 'define'
                return eval_define(expr.cdr, env)

              when 'define-values'
                return eval_define_values(expr.cdr, env)

              when 'set!'
                name = expr.cdr.car
                val = eval_expr(expr.cdr.cdr.car, env)
                env.set!(name, val)
                return VOID

              when 'lambda'
                params = expr.cdr.car
                body = expr.cdr.cdr
                return SchemeProcedure.new(params, body, env)

              when 'begin'
                body = expr.cdr
                return VOID if body.is_a?(SchemeNull)

                current = body
                while current.is_a?(SchemePair)
                  if current.cdr.is_a?(SchemeNull)
                    expr = current.car
                    break
                  end
                  eval_expr(current.car, env)
                  current = current.cdr
                end
                next  # tail call in last expr

              when 'let'
                result = eval_let(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'let*'
                result = eval_let_star(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'letrec'
                result = eval_letrec(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'letrec*'
                result = eval_letrec_star(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'do'
                result = eval_do(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'delay'
                thunk_body = expr.cdr.car
                thunk_env = env
                return SchemePromise.new(-> { eval_expr(thunk_body, thunk_env) })

              when 'delay-force', 'make-promise'
                thunk_body = expr.cdr.car
                thunk_env = env
                return SchemePromise.new(-> { eval_expr(thunk_body, thunk_env) })

              when 'force'
                promise = eval_expr(expr.cdr.car, env)
                unless promise.is_a?(SchemePromise)
                  return promise
                end
                until promise.forced
                  val = promise.thunk.call
                  if val.is_a?(SchemePromise)
                    promise.instance_variable_set(:@thunk, val.thunk) unless val.forced
                    promise.value = val.value
                    promise.forced = val.forced
                  else
                    promise.value = val
                    promise.forced = true
                  end
                end
                return promise.value

              when 'quasiquote'
                return eval_quasiquote(expr.cdr.car, env, 0)

              when 'define-syntax'
                return eval_define_syntax(expr.cdr, env)

              when 'let-syntax', 'letrec-syntax'
                return eval_let_syntax(expr.cdr, env)

              when 'syntax-rules'
                return eval_syntax_rules(expr.cdr, env)

              when 'define-record-type'
                return eval_define_record_type(expr.cdr, env)

              when 'case'
                result = eval_case(expr.cdr, env)
                if result.is_a?(SchemeTailCall)
                  expr = result.expr
                  env = result.env
                  next
                end
                return result

              when 'parameterize'
                return eval_parameterize(expr.cdr, env)

              when 'receive'
                # SRFI-8 receive
                return eval_receive(expr.cdr, env)

              when 'fluid-let'
                return eval_fluid_let(expr.cdr, env)

              when 'values'
                vals = expr.cdr
                args = []
                current = vals
                while current.is_a?(SchemePair)
                  args << eval_expr(current.car, env)
                  current = current.cdr
                end
                return args.length == 1 ? args[0] : SchemeValues.new(args)

              when 'call-with-values'
                prod = eval_expr(expr.cdr.car, env)
                cons = eval_expr(expr.cdr.cdr.car, env)
                result = apply(prod, [])
                args = result.is_a?(SchemeValues) ? result.values : [result]
                return apply(cons, args)

              when 'include'
                return eval_include(expr.cdr, env)

              when 'guard'
                return eval_guard(expr.cdr, env)

              when 'let-values'
                return eval_let_values(expr.cdr, env)

              when 'let*-values'
                return eval_let_star_values(expr.cdr, env)

              when 'define-syntax'
                return eval_define_syntax(expr.cdr, env)
              end
            end

            # Function application
            proc = eval_expr(head, env)

            # Check for macro
            if proc.is_a?(SchemeMacro)
              expanded = expand_macro(proc, expr)
              expr = expanded
              next
            end

            args = eval_args(expr.cdr, env)

            case proc
            when SchemePrimitive
              return proc.call(*args)
            when SchemeProcedure
              new_env = bind_args(proc, args)
              body = proc.body
              # Execute body with tail call in last position
              result = eval_body(body, new_env)
              if result.is_a?(SchemeTailCall)
                expr = result.expr
                env = result.env
                next
              end
              return result
            when SchemeContinuation
              throw(proc.tag, args.length == 1 ? args[0] : SchemeValues.new(args))
            else
              raise TypeError, "Not a procedure: #{scheme_write(proc)}"
            end

          else
            return expr
          end
        end
      end

      def apply(proc, args)
        case proc
        when SchemePrimitive
          proc.call(*args)
        when SchemeProcedure
          new_env = bind_args(proc, args)
          result = eval_body(proc.body, new_env)
          if result.is_a?(SchemeTailCall)
            eval_expr(result.expr, result.env)
          else
            result
          end
        when SchemeContinuation
          throw(proc.tag, args.length == 1 ? args[0] : SchemeValues.new(args))
        else
          raise TypeError, "Not a procedure: #{scheme_write(proc)}"
        end
      end

      def call_with_cc(proc)
        tag = :"cc_#{object_id}_#{rand(100_000)}"
        cont = SchemeContinuation.new(tag)
        result = catch(tag) do
          apply(proc, [cont])
        end
        result
      end

      private

      def eval_args(args_list, env)
        args = []
        current = args_list
        while current.is_a?(SchemePair)
          args << eval_expr(current.car, env)
          current = current.cdr
        end
        args
      end

      def bind_args(proc, args)
        params = proc.params
        rest_param = proc.rest_param
        env = proc.env

        if rest_param
          if args.length < params.length
            raise ArityError, "#{proc.name || 'lambda'}: expected at least #{params.length} args, got #{args.length}"
          end

          new_env = Environment.new(env)
          params.each_with_index { |p, i| new_env.define(p, args[i]) }
          rest_args = args[params.length..]
          new_env.define(rest_param, Sucheme.array_to_list(rest_args))
          new_env
        else
          if args.length != params.length
            raise ArityError, "#{proc.name || 'lambda'}: expected #{params.length} args, got #{args.length}"
          end

          new_env = Environment.new(env)
          params.each_with_index { |p, i| new_env.define(p, args[i]) }
          new_env
        end
      end

      def eval_body(body, env)
        # Process internal defines
        current = body
        defines = []
        exprs_start = body

        # Collect internal defines
        temp = body
        while temp.is_a?(SchemePair)
          expr = temp.car
          if expr.is_a?(SchemePair) && expr.car.is_a?(SchemeSymbol) &&
             (expr.car.name == 'define' || expr.car.name == 'define-syntax')
            defines << expr
            exprs_start = temp.cdr
            temp = temp.cdr
          else
            break
          end
        end

        # If there are internal defines, create a letrec*-like environment
        if defines.any?
          inner_env = Environment.new(env)
          defines.each { |d| eval_expr(d, inner_env) }
          env = inner_env
          body = exprs_start
        end

        return VOID if body.is_a?(SchemeNull)

        current = body
        loop do
          if current.cdr.is_a?(SchemeNull)
            # Last expression - tail call
            return SchemeTailCall.new(current.car, env)
          end

          eval_expr(current.car, env)
          current = current.cdr
        end
      end

      def eval_define(rest, env)
        target = rest.car
        if target.is_a?(SchemeSymbol)
          # (define name expr)
          val = rest.cdr.is_a?(SchemeNull) ? VOID : eval_expr(rest.cdr.car, env)
          val.name = target.name if val.is_a?(SchemeProcedure) && val.name.nil?
          env.define(target, val)
        elsif target.is_a?(SchemePair)
          # (define (name params...) body...)
          name = target.car
          params = target.cdr
          body = rest.cdr
          proc = SchemeProcedure.new(params, body, env, name: name.name)
          env.define(name, proc)
        else
          raise ParseError, "Invalid define syntax"
        end
        VOID
      end

      def eval_define_values(rest, env)
        formals = rest.car
        expr = rest.cdr.car
        result = eval_expr(expr, env)
        values = result.is_a?(SchemeValues) ? result.values : [result]
        names = []
        current = formals
        while current.is_a?(SchemePair)
          names << current.car
          current = current.cdr
        end
        names.each_with_index { |n, i| env.define(n, values[i]) }
        VOID
      end

      def eval_let(rest, env)
        binding_list = rest.car
        body = rest.cdr

        # Named let: (let name ((var init)...) body...)
        if binding_list.is_a?(SchemeSymbol)
          name = binding_list
          binding_list = body.car
          body = body.cdr
        else
          name = nil
        end

        bindings = []
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          var = pair.car
          init = eval_expr(pair.cdr.car, env)
          bindings << [var, init]
          current = current.cdr
        end

        new_env = Environment.new(env)
        bindings.each { |var, val| new_env.define(var, val) }

        if name
          # Named let creates a recursive procedure
          params = Sucheme.array_to_list(bindings.map(&:first))
          proc = SchemeProcedure.new(params, body, new_env, name: name.name)
          new_env.define(name, proc)
        end

        eval_body(body, new_env)
      end

      def eval_let_star(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = env
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          var = pair.car
          init = eval_expr(pair.cdr.car, new_env)
          inner = Environment.new(new_env)
          inner.define(var, init)
          new_env = inner
          current = current.cdr
        end

        eval_body(body, new_env)
      end

      def eval_letrec(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = Environment.new(env)

        # First pass: define all vars as undefined
        names = []
        inits = []
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          names << pair.car
          inits << pair.cdr.car
          new_env.define(pair.car, VOID)
          current = current.cdr
        end

        # Second pass: evaluate and assign
        names.each_with_index do |name, i|
          val = eval_expr(inits[i], new_env)
          val.name = name.name if val.is_a?(SchemeProcedure) && val.name.nil?
          new_env.define(name, val)
        end

        eval_body(body, new_env)
      end

      def eval_letrec_star(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = Environment.new(env)

        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          var = pair.car
          new_env.define(var, VOID)
          val = eval_expr(pair.cdr.car, new_env)
          val.name = var.name if val.is_a?(SchemeProcedure) && val.name.nil?
          new_env.define(var, val)
          current = current.cdr
        end

        eval_body(body, new_env)
      end

      def eval_cond(clauses, env)
        current = clauses
        while current.is_a?(SchemePair)
          clause = current.car
          test = clause.car
          consequent = clause.cdr

          if test.is_a?(SchemeSymbol) && test.name == 'else'
            # else clause
            return eval_body(consequent, env)
          end

          val = eval_expr(test, env)
          if val != false
            if consequent.is_a?(SchemeNull)
              return val
            elsif consequent.car.is_a?(SchemeSymbol) && consequent.car.name == '=>'
              # (cond (test => proc))
              proc = eval_expr(consequent.cdr.car, env)
              return apply(proc, [val])
            else
              return eval_body(consequent, env)
            end
          end
          current = current.cdr
        end
        VOID
      end

      def eval_case(rest, env)
        key = eval_expr(rest.car, env)
        clauses = rest.cdr

        current = clauses
        while current.is_a?(SchemePair)
          clause = current.car
          datum_list = clause.car
          body = clause.cdr

          if datum_list.is_a?(SchemeSymbol) && datum_list.name == 'else'
            return eval_body(body, env)
          end

          # Check if key matches any datum
          match = false
          datum_current = datum_list
          while datum_current.is_a?(SchemePair)
            if scheme_eqv?(key, datum_current.car)
              match = true
              break
            end
            datum_current = datum_current.cdr
          end

          if match
            # Check for => syntax
            if body.car.is_a?(SchemeSymbol) && body.car.name == '=>'
              proc = eval_expr(body.cdr.car, env)
              return apply(proc, [key])
            end
            return eval_body(body, env)
          end

          current = current.cdr
        end
        VOID
      end

      def eval_do(rest, env)
        var_specs = rest.car
        test_and_result = rest.cdr.car
        commands = rest.cdr.cdr

        # Initialize variables
        new_env = Environment.new(env)
        vars = []
        current = var_specs
        while current.is_a?(SchemePair)
          spec = current.car
          var = spec.car
          init = eval_expr(spec.cdr.car, env)
          step = spec.cdr.cdr.is_a?(SchemeNull) ? nil : spec.cdr.cdr.car
          new_env.define(var, init)
          vars << [var, step]
          current = current.cdr
        end

        test = test_and_result.car
        result_exprs = test_and_result.cdr

        loop do
          test_val = eval_expr(test, new_env)
          if test_val != false
            # Test is true, return result
            if result_exprs.is_a?(SchemeNull)
              return VOID
            else
              return eval_body(result_exprs, new_env)
            end
          end

          # Execute commands
          cmd = commands
          while cmd.is_a?(SchemePair)
            eval_expr(cmd.car, new_env)
            cmd = cmd.cdr
          end

          # Step variables
          new_vals = vars.map do |var, step|
            step ? eval_expr(step, new_env) : new_env.lookup(var)
          end
          vars.each_with_index do |(var, _step), i|
            new_env.define(var, new_vals[i])
          end
        end
      end

      def eval_quasiquote(tmpl, env, depth)
        case tmpl
        when SchemePair
          if tmpl.car.is_a?(SchemeSymbol)
            case tmpl.car.name
            when 'unquote'
              if depth.zero?
                return eval_expr(tmpl.cdr.car, env)
              else
                return SchemePair.new(
                  SchemeSymbol.intern('unquote'),
                  SchemePair.new(eval_quasiquote(tmpl.cdr.car, env, depth - 1), NULL)
                )
              end
            when 'quasiquote'
              return SchemePair.new(
                SchemeSymbol.intern('quasiquote'),
                SchemePair.new(eval_quasiquote(tmpl.cdr.car, env, depth + 1), NULL)
              )
            end
          end

          # Check for unquote-splicing in car
          if tmpl.car.is_a?(SchemePair) &&
             tmpl.car.car.is_a?(SchemeSymbol) &&
             tmpl.car.car.name == 'unquote-splicing'
            if depth.zero?
              spliced = eval_expr(tmpl.car.cdr.car, env)
              rest = eval_quasiquote(tmpl.cdr, env, depth)
              # Append spliced to rest
              return append_lists(spliced, rest)
            end
          end

          car = eval_quasiquote(tmpl.car, env, depth)
          cdr = eval_quasiquote(tmpl.cdr, env, depth)
          SchemePair.new(car, cdr)

        when SchemeVector
          items = tmpl.data.flat_map do |item|
            if item.is_a?(SchemePair) && item.car.is_a?(SchemeSymbol) && item.car.name == 'unquote-splicing' && depth.zero?
              spliced = eval_expr(item.cdr.car, env)
              lst_to_array(spliced)
            else
              [eval_quasiquote(item, env, depth)]
            end
          end
          SchemeVector.new(items)

        else
          tmpl
        end
      end

      def append_lists(a, b)
        return b if a.is_a?(SchemeNull)

        raise TypeError, "unquote-splicing: not a list: #{scheme_write(a)}" unless a.is_a?(SchemePair)

        SchemePair.new(a.car, append_lists(a.cdr, b))
      end

      def lst_to_array(lst)
        arr = []
        current = lst
        while current.is_a?(SchemePair)
          arr << current.car
          current = current.cdr
        end
        arr
      end

      def eval_define_syntax(rest, env)
        name = rest.car
        transformer = eval_expr(rest.cdr.car, env)
        macro = if transformer.is_a?(SchemeMacro)
                  SchemeMacro.new(name.name, transformer.literals, transformer.rules)
                else
                  transformer
                end
        env.define(name, macro)
        VOID
      end

      def eval_let_syntax(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = Environment.new(env)
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          name = pair.car
          transformer = eval_expr(pair.cdr.car, env)
          new_env.define(name, transformer)
          current = current.cdr
        end

        eval_body(body, new_env)
        result = VOID
        c = body
        while c.is_a?(SchemePair)
          result = eval_expr(c.car, new_env)
          c = c.cdr
        end
        result
      end

      def eval_syntax_rules(rest, env)
        literals = rest.car
        rules = rest.cdr

        literal_names = []
        current = literals
        while current.is_a?(SchemePair)
          literal_names << current.car.name
          current = current.cdr
        end

        rule_list = []
        current = rules
        while current.is_a?(SchemePair)
          rule = current.car
          pattern = rule.car
          template = rule.cdr.car
          rule_list << [pattern, template]
          current = current.cdr
        end

        SchemeMacro.new(nil, literal_names, rule_list)
      end

      def expand_macro(macro, form)
        macro.rules.each do |pattern, template|
          bindings = {}
          if match_pattern(pattern, form, macro.literals, bindings)
            return instantiate_template(template, bindings)
          end
        end
        raise EvalError, "No matching syntax rule for: #{scheme_write(form)}"
      end

      def match_pattern(pattern, form, literals, bindings)
        case pattern
        when SchemeSymbol
          if literals.include?(pattern.name)
            # Literal must match exactly
            form.is_a?(SchemeSymbol) && form.name == pattern.name
          elsif pattern.name == '_'
            true
          else
            # Pattern variable - matches anything
            bindings[pattern.name] = form
            true
          end
        when SchemePair
          if pattern.car.is_a?(SchemeSymbol) && pattern.car.name == '...'
            # Shouldn't happen at top level
            false
          elsif pattern.cdr.is_a?(SchemePair) &&
                pattern.cdr.car.is_a?(SchemeSymbol) &&
                pattern.cdr.car.name == '...'
            # Pattern with ellipsis: (pat ... rest)
            match_ellipsis(pattern.car, pattern.cdr.cdr, form, literals, bindings)
          else
            return false unless form.is_a?(SchemePair)

            match_pattern(pattern.car, form.car, literals, bindings) &&
              match_pattern(pattern.cdr, form.cdr, literals, bindings)
          end
        when SchemeNull
          form.is_a?(SchemeNull)
        when SchemeVector
          return false unless form.is_a?(SchemeVector)
          return false unless pattern.length == form.length

          pattern.data.zip(form.data).all? { |p, f| match_pattern(p, f, literals, bindings) }
        else
          # Literal datum
          form == pattern
        end
      end

      def match_ellipsis(sub_pattern, rest_pattern, form, literals, bindings)
        # Collect elements for the ellipsis pattern variable
        # Figure out how many elements remain for rest_pattern
        rest_len = list_length(rest_pattern)
        form_len = list_length(form)
        return false if form_len < rest_len

        ellipsis_count = form_len - rest_len

        # Collect pattern variables in sub_pattern
        pvars = collect_pattern_vars(sub_pattern, literals)
        pvars.each { |v| bindings[v] = [] }

        current = form
        ellipsis_count.times do
          sub_bindings = {}
          return false unless match_pattern(sub_pattern, current.car, literals, sub_bindings)

          pvars.each { |v| bindings[v] << (sub_bindings[v] || VOID) }
          current = current.cdr
        end

        # Match rest
        match_pattern(rest_pattern, current, literals, bindings)
      end

      def collect_pattern_vars(pattern, literals)
        vars = []
        case pattern
        when SchemeSymbol
          vars << pattern.name unless literals.include?(pattern.name) || pattern.name == '_'
        when SchemePair
          vars += collect_pattern_vars(pattern.car, literals)
          vars += collect_pattern_vars(pattern.cdr, literals)
        end
        vars
      end

      def list_length(lst)
        count = 0
        current = lst
        while current.is_a?(SchemePair)
          count += 1
          current = current.cdr
        end
        count
      end

      def instantiate_template(template, bindings)
        case template
        when SchemeSymbol
          bindings.key?(template.name) ? bindings[template.name] : template
        when SchemePair
          # Check for ellipsis in cdr
          if template.cdr.is_a?(SchemePair) &&
             template.cdr.car.is_a?(SchemeSymbol) &&
             template.cdr.car.name == '...'
            # Expand ellipsis
            pvars = collect_template_vars(template.car, bindings)
            if pvars.any? && bindings[pvars.first].is_a?(Array)
              count = bindings[pvars.first].length
              expanded = (0...count).map do |i|
                sub_bindings = bindings.dup
                pvars.each { |v| sub_bindings[v] = bindings[v][i] }
                instantiate_template(template.car, sub_bindings)
              end
              rest = instantiate_template(template.cdr.cdr, bindings)
              expanded.reverse_each { |e| rest = SchemePair.new(e, rest) }
              rest
            else
              rest = instantiate_template(template.cdr.cdr, bindings)
              SchemePair.new(instantiate_template(template.car, bindings), rest)
            end
          else
            car = instantiate_template(template.car, bindings)
            cdr = instantiate_template(template.cdr, bindings)
            SchemePair.new(car, cdr)
          end
        when SchemeNull
          template
        when SchemeVector
          SchemeVector.new(template.data.map { |e| instantiate_template(e, bindings) })
        else
          template
        end
      end

      def collect_template_vars(template, bindings)
        vars = []
        case template
        when SchemeSymbol
          vars << template.name if bindings.key?(template.name) && bindings[template.name].is_a?(Array)
        when SchemePair
          vars += collect_template_vars(template.car, bindings)
          vars += collect_template_vars(template.cdr, bindings)
        end
        vars
      end

      def eval_define_record_type(rest, env)
        type_name = rest.car
        constructor_spec = rest.cdr.car
        predicate_name = rest.cdr.cdr.car
        field_specs = rest.cdr.cdr.cdr

        constructor_name = constructor_spec.car
        constructor_fields = []
        current = constructor_spec.cdr
        while current.is_a?(SchemePair)
          constructor_fields << current.car.name
          current = current.cdr
        end

        # Collect all fields
        all_fields = []
        current = field_specs
        while current.is_a?(SchemePair)
          spec = current.car
          all_fields << {
            name: spec.car.name,
            accessor: spec.cdr.car,
            modifier: spec.cdr.cdr.is_a?(SchemePair) ? spec.cdr.cdr.car : nil
          }
          current = current.cdr
        end

        type_tag = type_name.name.to_sym

        # Constructor
        env.define(constructor_name, SchemePrimitive.new(constructor_name.name) do |*args|
          if args.length != constructor_fields.length
            raise ArityError, "#{constructor_name.name}: expected #{constructor_fields.length} args"
          end

          record = { :__type__ => type_tag }
          constructor_fields.each_with_index { |f, i| record[f] = args[i] }
          # Add any fields not in constructor with default nil
          all_fields.each { |f| record[f[:name]] ||= VOID }
          record
        end)

        # Predicate
        env.define(predicate_name, SchemePrimitive.new(predicate_name.name) do |obj|
          obj.is_a?(Hash) && obj[:__type__] == type_tag
        end)

        # Accessors and mutators
        all_fields.each do |field|
          env.define(field[:accessor], SchemePrimitive.new(field[:accessor].name) do |obj|
            raise TypeError, "#{field[:accessor].name}: not a #{type_name.name}" unless obj.is_a?(Hash) && obj[:__type__] == type_tag

            obj[field[:name]]
          end)

          if field[:modifier]
            env.define(field[:modifier], SchemePrimitive.new(field[:modifier].name) do |obj, val|
              raise TypeError, "#{field[:modifier].name}: not a #{type_name.name}" unless obj.is_a?(Hash) && obj[:__type__] == type_tag

              obj[field[:name]] = val
              VOID
            end)
          end
        end

        VOID
      end

      def eval_parameterize(rest, env)
        bindings = rest.car
        body = rest.cdr

        params = []
        current = bindings
        while current.is_a?(SchemePair)
          pair = current.car
          param = eval_expr(pair.car, env)
          val = eval_expr(pair.cdr.car, env)
          params << [param, val]
          current = current.cdr
        end

        params.each { |param, val| param.push(val) }
        begin
          result = VOID
          c = body
          while c.is_a?(SchemePair)
            result = eval_expr(c.car, env)
            c = c.cdr
          end
          result
        ensure
          params.each { |param, _| param.pop }
        end
      end

      def eval_fluid_let(rest, env)
        bindings = rest.car
        body = rest.cdr

        saved = {}
        current = bindings
        while current.is_a?(SchemePair)
          pair = current.car
          var = pair.car
          val = eval_expr(pair.cdr.car, env)
          saved[var.name] = env.lookup(var)
          env.set!(var, val)
          current = current.cdr
        end

        begin
          result = VOID
          c = body
          while c.is_a?(SchemePair)
            result = eval_expr(c.car, env)
            c = c.cdr
          end
          result
        ensure
          saved.each { |name, val| env.set!(SchemeSymbol.intern(name), val) }
        end
      end

      def eval_receive(rest, env)
        formals = rest.car
        expr = rest.cdr.car
        body = rest.cdr.cdr

        result = eval_expr(expr, env)
        values = result.is_a?(SchemeValues) ? result.values : [result]

        new_env = Environment.new(env)

        if formals.is_a?(SchemeSymbol)
          new_env.define(formals, Sucheme.array_to_list(values))
        else
          current_f = formals
          idx = 0
          while current_f.is_a?(SchemePair)
            new_env.define(current_f.car, values[idx] || VOID)
            current_f = current_f.cdr
            idx += 1
          end
          new_env.define(current_f, Sucheme.array_to_list(values[idx..])) if current_f.is_a?(SchemeSymbol)
        end

        result = VOID
        c = body
        while c.is_a?(SchemePair)
          result = eval_expr(c.car, new_env)
          c = c.cdr
        end
        result
      end

      def eval_include(rest, env)
        result = VOID
        current = rest
        while current.is_a?(SchemePair)
          path = eval_expr(current.car, env)
          raise TypeError, "include: not a string" unless path.is_a?(String)

          source = File.read(path)
          exprs = Parser.parse(source, filename: path)
          exprs.each { |e| result = eval_expr(e, env) }
          current = current.cdr
        end
        result
      end

      def eval_guard(rest, env)
        var_and_clauses = rest.car
        body = rest.cdr

        var = var_and_clauses.car
        clauses = var_and_clauses.cdr

        begin
          result = VOID
          c = body
          while c.is_a?(SchemePair)
            result = eval_expr(c.car, env)
            c = c.cdr
          end
          result
        rescue SuchemeError, StandardError => e
          guard_env = Environment.new(env)
          guard_env.define(var, e.message)

          matched = false
          current = clauses
          while current.is_a?(SchemePair)
            clause = current.car
            test = clause.car
            consequent = clause.cdr

            if test.is_a?(SchemeSymbol) && test.name == 'else'
              matched = true
              result = VOID
              c = consequent
              while c.is_a?(SchemePair)
                result = eval_expr(c.car, guard_env)
                c = c.cdr
              end
              return result
            end

            val = eval_expr(test, guard_env)
            if val != false
              matched = true
              if consequent.is_a?(SchemeNull)
                return val
              end

              result = VOID
              c = consequent
              while c.is_a?(SchemePair)
                result = eval_expr(c.car, guard_env)
                c = c.cdr
              end
              return result
            end

            current = current.cdr
          end

          raise unless matched
        end
      end

      def eval_let_values(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = Environment.new(env)
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          formals = pair.car
          expr = pair.cdr.car
          result = eval_expr(expr, env)
          values = result.is_a?(SchemeValues) ? result.values : [result]

          f = formals
          idx = 0
          while f.is_a?(SchemePair)
            new_env.define(f.car, values[idx] || VOID)
            f = f.cdr
            idx += 1
          end
          current = current.cdr
        end

        eval_body(body, new_env)
        result = VOID
        c = body
        while c.is_a?(SchemePair)
          result = eval_expr(c.car, new_env)
          c = c.cdr
        end
        result
      end

      def eval_let_star_values(rest, env)
        binding_list = rest.car
        body = rest.cdr

        new_env = env
        current = binding_list
        while current.is_a?(SchemePair)
          pair = current.car
          formals = pair.car
          expr = pair.cdr.car
          result = eval_expr(expr, new_env)
          values = result.is_a?(SchemeValues) ? result.values : [result]

          inner = Environment.new(new_env)
          f = formals
          idx = 0
          while f.is_a?(SchemePair)
            inner.define(f.car, values[idx] || VOID)
            f = f.cdr
            idx += 1
          end
          new_env = inner
          current = current.cdr
        end

        result = VOID
        c = body
        while c.is_a?(SchemePair)
          result = eval_expr(c.car, new_env)
          c = c.cdr
        end
        result
      end

      def scheme_write(obj)
        case obj
        when String
          "\"#{obj.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\t", '\\t').gsub("\r", '\\r')}\""
        when SchemeChar  then obj.write_repr
        when SchemeNull  then '()'
        when SchemeVoid  then ''
        when true        then '#t'
        when false       then '#f'
        else obj.to_s
        end
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

      def load_scheme_stdlib(env)
        stdlib = <<~SCHEME
          (define-syntax and
            (syntax-rules ()
              ((and) #t)
              ((and e) e)
              ((and e1 e2 ...)
               (if e1 (and e2 ...) #f))))

          (define-syntax or
            (syntax-rules ()
              ((or) #f)
              ((or e) e)
              ((or e1 e2 ...)
               (let ((t e1))
                 (if t t (or e2 ...))))))

          (define-syntax when
            (syntax-rules ()
              ((when test body ...)
               (if test (begin body ...) (void)))))

          (define-syntax unless
            (syntax-rules ()
              ((unless test body ...)
               (if test (void) (begin body ...)))))

          (define-syntax cond
            (syntax-rules (else =>)
              ((cond (else e ...)) (begin e ...))
              ((cond (test => proc) rest ...)
               (let ((t test))
                 (if t (proc t) (cond rest ...))))
              ((cond (test) rest ...)
               (let ((t test))
                 (if t t (cond rest ...))))
              ((cond (test e ...) rest ...)
               (if test (begin e ...) (cond rest ...)))
              ((cond) (void))))

          (define-syntax case
            (syntax-rules (else =>)
              ((case key (else e ...)) (begin e ...))
              ((case key ((d ...) => proc) rest ...)
               (if (memv key '(d ...))
                   (proc key)
                   (case key rest ...)))
              ((case key ((d ...) e ...) rest ...)
               (if (memv key '(d ...))
                   (begin e ...)
                   (case key rest ...)))
              ((case key) (void))))

          (define-syntax let
            (syntax-rules ()
              ((let ((var init) ...) body ...)
               ((lambda (var ...) body ...) init ...))
              ((let name ((var init) ...) body ...)
               (letrec ((name (lambda (var ...) body ...)))
                 (name init ...)))))

          (define-syntax let*
            (syntax-rules ()
              ((let* () body ...) (begin body ...))
              ((let* ((var init) rest ...) body ...)
               (let ((var init)) (let* (rest ...) body ...)))))

          (define-syntax letrec
            (syntax-rules ()
              ((letrec ((var init) ...) body ...)
               (let ((var (void)) ...)
                 (set! var init) ...
                 body ...))))

          (define-syntax letrec*
            (syntax-rules ()
              ((letrec* ((var init) ...) body ...)
               (let ()
                 (define var init) ...
                 body ...))))

          (define-syntax do
            (syntax-rules ()
              ((do ((var init step ...) ...)
                   (test result ...)
                 command ...)
               (let loop ((var init) ...)
                 (if test
                     (begin result ...)
                     (begin command ... (loop (if (null? '(step ...)) var (car '(step ...))) ...)))))))

          (define-syntax fluid-let
            (syntax-rules ()
              ((fluid-let ((var val) ...) body ...)
               (let ((old-var var) ...)
                 (set! var val) ...
                 (let ((result (begin body ...)))
                   (set! var old-var) ...
                   result)))))

          (define-syntax while
            (syntax-rules ()
              ((while test body ...)
               (let loop ()
                 (when test body ... (loop))))))

          (define-syntax dotimes
            (syntax-rules ()
              ((dotimes (var n) body ...)
               (let loop ((var 0))
                 (when (< var n)
                   body ...
                   (loop (+ var 1)))))))

          (define-syntax receive
            (syntax-rules ()
              ((receive formals expression body ...)
               (call-with-values
                 (lambda () expression)
                 (lambda formals body ...)))))

          (define-syntax define-values
            (syntax-rules ()
              ((define-values (var ...) expr)
               (call-with-values
                 (lambda () expr)
                 (lambda (var ...) (define var var) ... (void))))))

          (define-syntax parameterize
            (syntax-rules ()
              ((parameterize ((param val) ...) body ...)
               (let ((p param) ...)
                 (dynamic-wind
                   (lambda () (p val) ...)
                   (lambda () body ...)
                   (lambda () (p) ...))))))

          (define (not x) (if x #f #t))

          (define (boolean=? . bools)
            (or (apply = (map (lambda (b) (if b 1 0)) bools))
                #f))

          (define (list? x)
            (let loop ((x x) (y x))
              (cond ((null? x) #t)
                    ((not (pair? x)) #f)
                    ((null? (cdr x)) #t)
                    ((not (pair? (cdr x))) #f)
                    ((eq? (cddr x) y) #f)
                    (else (loop (cddr x) (cdr y))))))

          (define (make-list n . rest)
            (let ((fill (if (null? rest) #f (car rest))))
              (let loop ((i n) (acc '()))
                (if (= i 0) acc (loop (- i 1) (cons fill acc))))))

          (define (last-pair lst)
            (if (null? (cdr lst)) lst (last-pair (cdr lst))))

          (define (list-copy lst)
            (if (null? lst) '()
                (cons (car lst) (list-copy (cdr lst)))))

          (define (take lst n)
            (if (= n 0) '()
                (cons (car lst) (take (cdr lst) (- n 1)))))

          (define (drop lst n)
            (if (= n 0) lst (drop (cdr lst) (- n 1))))

          (define (flatten lst)
            (cond ((null? lst) '())
                  ((pair? (car lst))
                   (append (flatten (car lst)) (flatten (cdr lst))))
                  (else (cons (car lst) (flatten (cdr lst))))))

          (define (zip . lists)
            (apply map list lists))

          (define (range start . rest)
            (let* ((end (if (null? rest) start (car rest)))
                   (start (if (null? rest) 0 start))
                   (step (if (or (null? rest) (null? (cdr rest))) 1 (cadr rest))))
              (let loop ((i start) (acc '()))
                (if (>= i end)
                    (reverse acc)
                    (loop (+ i step) (cons i acc))))))

          (define (compose . procs)
            (if (null? procs)
                (lambda (x) x)
                (lambda (x)
                  ((car procs) ((apply compose (cdr procs)) x)))))

          (define (curry f . args)
            (lambda rest (apply f (append args rest))))

          (define (flip f)
            (lambda (x y) (f y x)))

          (define (identity x) x)

          (define (const x) (lambda _ x))

          (define (negate pred)
            (lambda args (not (apply pred args))))

          (define (1+ n) (+ n 1))
          (define (1- n) (- n 1))

          (define (square x) (* x x))

          (define (char=? . chars)
            (apply = (map char->integer chars)))

          (define (string-trim str . rest)
            (let ((chars (if (null? rest) char-whitespace? (car rest))))
              (let loop ((i 0))
                (cond ((= i (string-length str)) "")
                      ((if (procedure? chars)
                           (chars (string-ref str i))
                           (char=? (string-ref str i) chars))
                       (loop (+ i 1)))
                      (else (substring str i (string-length str)))))))

          (define (string-trim-right str . rest)
            (let ((chars (if (null? rest) char-whitespace? (car rest))))
              (let loop ((i (- (string-length str) 1)))
                (cond ((< i 0) "")
                      ((if (procedure? chars)
                           (chars (string-ref str i))
                           (char=? (string-ref str i) chars))
                       (loop (- i 1)))
                      (else (substring str 0 (+ i 1)))))))

          (define (number->string* n . rest)
            (let ((radix (if (null? rest) 10 (car rest))))
              (number->string n radix)))

          (define (exact-integer? n)
            (and (integer? n) (exact? n)))

          (define (exact-rational? n)
            (and (rational? n) (exact? n)))

          (define (nan? x)
            (and (real? x) (not (= x x))))

          (define (infinite? x)
            (and (real? x) (not (finite? x)) (not (nan? x))))

          (define (finite? x)
            (and (real? x) (< (abs x) +inf.0)))

          (define (char->digit ch . rest)
            (let ((radix (if (null? rest) 10 (car rest))))
              (let ((n (- (char->integer ch) (char->integer #\0))))
                (if (and (>= n 0) (< n radix))
                    n
                    (let ((n (- (char->integer (char-downcase ch)) (char->integer #\a) -10)))
                      (if (and (>= n 10) (< n radix))
                          n
                          #f))))))

          (define (digit->char d . rest)
            (let ((radix (if (null? rest) 10 (car rest))))
              (if (< d 10)
                  (integer->char (+ d (char->integer #\0)))
                  (integer->char (+ d -10 (char->integer #\a))))))

          (define (with-values thunk receiver)
            (call-with-values thunk receiver))

          (define (call-with-string-output-port proc)
            (let ((port (open-output-string)))
              (proc port)
              (get-output-string port)))

          (define (pp x) (write x) (newline))
          (define (println x) (display x) (newline))
        SCHEME

        begin
          exprs = Parser.parse(stdlib, filename: '<stdlib>')
          exprs.each { |e| eval_expr(e, env) }
        rescue => ex
          # Log stdlib errors but don't crash
          $stderr.puts "Warning: stdlib error: #{ex.message}" if ENV['SUCHEME_DEBUG']
        end
      end
    end
  end
end
