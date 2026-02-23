# frozen_string_literal: true

module Sucheme
  class Repl
    PROMPT = 'sucheme> '
    CONTINUE_PROMPT = '       > '

    def initialize(env: nil, quiet: false, output: $stdout, input: $stdin)
      @env = env || Evaluator.make_global_env
      @quiet = quiet
      @output = output
      @input = input
    end

    def run
      @output.puts "Sucheme #{VERSION} - R5RS Scheme Interpreter" unless @quiet
      @output.puts "Type (exit) or Ctrl-D to quit." unless @quiet
      @output.puts unless @quiet

      loop do
        input = read_expression
        break if input.nil?

        next if input.strip.empty?

        begin
          exprs = Parser.parse(input)
          exprs.each do |expr|
            result = Evaluator.eval_expr(expr, @env)
            if result.is_a?(SchemeVoid)
              # Don't print void
            else
              @output.puts ";; => #{display_result(result)}"
            end
          end
        rescue SuchemeError => e
          @output.puts ";; Error: #{e.message}"
        rescue Interrupt
          @output.puts
          @output.puts ";; Interrupted. Type (exit) or Ctrl-D to quit."
        rescue => e
          @output.puts ";; Internal error: #{e.message}"
          @output.puts e.backtrace.first(3).map { |l| ";;   #{l}" }.join("\n") if ENV['SUCHEME_DEBUG']
        end
      end

      @output.puts "\nGoodbye!" unless @quiet
    end

    def eval_string(source)
      exprs = Parser.parse(source)
      result = VOID
      exprs.each { |expr| result = Evaluator.eval_expr(expr, @env) }
      result
    end

    private

    def read_expression
      buffer = +''
      prompt = PROMPT

      loop do
        @output.print(prompt) unless @quiet
        @output.flush

        line = @input.gets
        return nil if line.nil?  # EOF

        buffer << line
        prompt = CONTINUE_PROMPT

        # Check if parens are balanced
        break if balanced?(buffer)
      end

      buffer
    end

    def balanced?(str)
      # Remove strings and comments
      depth = 0
      in_string = false
      i = 0

      while i < str.length
        c = str[i]
        if in_string
          if c == '\\'
            i += 2
            next
          elsif c == '"'
            in_string = false
          end
        else
          case c
          when '"' then in_string = true
          when ';'
            # Skip to end of line
            i += 1 while i < str.length && str[i] != "\n"
          when '('
            depth += 1
          when ')'
            depth -= 1
          end
        end
        i += 1
      end

      depth <= 0 && !in_string
    end

    def display_result(val)
      case val
      when String
        "\"#{val.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\t", '\\t')}\""
      when SchemeChar  then val.write_repr
      when true        then '#t'
      when false       then '#f'
      else val.to_s
      end
    end
  end
end
