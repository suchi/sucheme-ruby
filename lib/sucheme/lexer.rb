# frozen_string_literal: true

require 'strscan'

module Sucheme
  # Token types
  TOKEN_LPAREN    = :lparen
  TOKEN_RPAREN    = :rparen
  TOKEN_HASH_LPAREN = :hash_lparen  # #(
  TOKEN_DOT       = :dot
  TOKEN_QUOTE     = :quote
  TOKEN_QUASIQUOTE = :quasiquote
  TOKEN_UNQUOTE   = :unquote
  TOKEN_UNQUOTE_SPLICING = :unquote_splicing
  TOKEN_DATUM_COMMENT = :datum_comment  # #;
  TOKEN_NUMBER    = :number
  TOKEN_STRING    = :string
  TOKEN_BOOL      = :bool
  TOKEN_CHAR      = :char
  TOKEN_SYMBOL    = :symbol
  TOKEN_EOF       = :eof

  Token = Struct.new(:type, :value, :line, :col)

  class Lexer
    # Characters that delimit tokens
    DELIMITERS = /[\s\(\)";,\[\]{}]/

    def initialize(source, filename: '<string>')
      @scanner = StringScanner.new(source)
      @filename = filename
      @line = 1
      @col = 1
    end

    def tokenize
      tokens = []
      loop do
        tok = next_token
        tokens << tok
        break if tok.type == TOKEN_EOF
      end
      tokens
    end

    def next_token
      skip_whitespace_and_comments
      return Token.new(TOKEN_EOF, nil, @line, @col) if @scanner.eos?

      line = @line
      col = @col

      ch = peek_char

      case ch
      when '('
        advance_char
        Token.new(TOKEN_LPAREN, '(', line, col)
      when ')'
        advance_char
        Token.new(TOKEN_RPAREN, ')', line, col)
      when "'"
        advance_char
        Token.new(TOKEN_QUOTE, "'", line, col)
      when '`'
        advance_char
        Token.new(TOKEN_QUASIQUOTE, '`', line, col)
      when ','
        advance_char
        if peek_char == '@'
          advance_char
          Token.new(TOKEN_UNQUOTE_SPLICING, ',@', line, col)
        else
          Token.new(TOKEN_UNQUOTE, ',', line, col)
        end
      when '"'
        lex_string(line, col)
      when '#'
        lex_hash(line, col)
      when '.'
        lex_dot_or_number(line, col)
      else
        lex_atom(line, col)
      end
    end

    private

    def peek_char
      @scanner.peek(1)
    end

    def advance_char
      ch = @scanner.getch
      if ch == "\n"
        @line += 1
        @col = 1
      else
        @col += 1
      end
      ch
    end

    def skip_whitespace_and_comments
      loop do
        # Skip whitespace
        if @scanner.match?(/[ \t\r\n]+/)
          ws = @scanner.scan(/[ \t\r\n]+/)
          ws.each_char do |c|
            if c == "\n"
              @line += 1
              @col = 1
            else
              @col += 1
            end
          end
          next
        end
        # Skip line comment
        if @scanner.match?(/;/)
          @scanner.scan(/[^\n]*/)
          @col += $~[0].length if $~
          next
        end
        # Skip block comment #| ... |#
        if @scanner.match?(/#\|/)
          @scanner.pos += 2
          @col += 2
          depth = 1
          until depth.zero? || @scanner.eos?
            if @scanner.match?(/#\|/)
              @scanner.pos += 2
              @col += 2
              depth += 1
            elsif @scanner.match?(/\|#/)
              @scanner.pos += 2
              @col += 2
              depth -= 1
            elsif @scanner.peek(1) == "\n"
              @scanner.pos += 1
              @line += 1
              @col = 1
            else
              @scanner.pos += 1
              @col += 1
            end
          end
          next
        end
        break
      end
    end

    def lex_string(line, col)
      advance_char  # consume opening "
      result = +''
      loop do
        raise LexError, "Unterminated string at #{@filename}:#{line}:#{col}" if @scanner.eos?

        ch = advance_char
        case ch
        when '"'
          break
        when '\\'
          esc = advance_char
          case esc
          when 'n'  then result << "\n"
          when 't'  then result << "\t"
          when 'r'  then result << "\r"
          when '\\' then result << "\\"
          when '"'  then result << '"'
          when '0'  then result << "\0"
          when 'a'  then result << "\a"
          when 'b'  then result << "\b"
          when 'f'  then result << "\f"
          when 'v'  then result << "\v"
          when 'x'
            # Hex escape \xNN;
            hex = +''
            until @scanner.eos? || peek_char == ';'
              hex << advance_char
            end
            advance_char if peek_char == ';'  # consume ;
            result << hex.to_i(16).chr(Encoding::UTF_8)
          else
            result << esc
          end
        else
          result << ch
        end
      end
      Token.new(TOKEN_STRING, result, line, col)
    end

    def lex_hash(line, col)
      advance_char  # consume #
      ch = peek_char
      case ch
      when '('
        advance_char
        Token.new(TOKEN_HASH_LPAREN, '#(', line, col)
      when 't'
        advance_char
        # Check for #true
        if @scanner.match?(/rue(?=#{DELIMITERS}|\z)/)
          @scanner.pos += 3
          @col += 3
        end
        Token.new(TOKEN_BOOL, true, line, col)
      when 'f'
        advance_char
        # Check for #false
        if @scanner.match?(/alse(?=#{DELIMITERS}|\z)/)
          @scanner.pos += 4
          @col += 4
        end
        Token.new(TOKEN_BOOL, false, line, col)
      when '\\'
        advance_char
        lex_character(line, col)
      when ';'
        advance_char
        Token.new(TOKEN_DATUM_COMMENT, '#;', line, col)
      when 'e', 'E', 'i', 'I'
        lex_exactness(line, col)
      when 'b', 'B', 'o', 'O', 'd', 'D', 'x', 'X'
        lex_radix(line, col)
      else
        raise LexError, "Unknown # syntax: ##{ch} at #{@filename}:#{line}:#{col}"
      end
    end

    def lex_character(line, col)
      if @scanner.eos?
        raise LexError, "Unexpected end after #\\ at #{@filename}:#{line}:#{col}"
      end

      # Check for named characters
      char_name = @scanner.scan(/[a-zA-Z]+/)
      if char_name
        @col += char_name.length
        ch = case char_name.downcase
             when 'space'     then ' '
             when 'newline'   then "\n"
             when 'tab'       then "\t"
             when 'return'    then "\r"
             when 'nul', 'null' then "\0"
             when 'escape', 'altmode' then "\e"
             when 'delete', 'rubout' then "\x7f"
             when 'backspace' then "\b"
             when 'page'      then "\f"
             when 'alarm'     then "\a"
             else
               if char_name.length == 1
                 char_name
               else
                 raise LexError, "Unknown character name: #{char_name} at #{@filename}:#{line}:#{col}"
               end
             end
        Token.new(TOKEN_CHAR, SchemeChar.new(ch), line, col)
      else
        ch = advance_char
        Token.new(TOKEN_CHAR, SchemeChar.new(ch), line, col)
      end
    end

    def lex_exactness(line, col)
      exact_ch = advance_char.downcase
      exact = exact_ch == 'e'
      # May be followed by radix
      radix = 10
      if @scanner.match?(/[bodxBODX]/i)
        radix_ch = advance_char.downcase
        radix = case radix_ch
                when 'b' then 2
                when 'o' then 8
                when 'd' then 10
                when 'x' then 16
                end
      end
      num_str = scan_number_chars(radix)
      parse_number(num_str, radix, exact, line, col)
    end

    def lex_radix(line, col)
      radix_ch = advance_char.downcase
      radix = case radix_ch
              when 'b' then 2
              when 'o' then 8
              when 'd' then 10
              when 'x' then 16
              end
      # May be followed by exactness
      exact = nil
      if @scanner.match?(/[eiEI]/)
        exact_ch = advance_char.downcase
        exact = exact_ch == 'e'
      end
      num_str = scan_number_chars(radix)
      parse_number(num_str, radix, exact, line, col)
    end

    def scan_number_chars(radix)
      chars = case radix
              when 2  then /[01+\-\.\/]+/
              when 8  then /[0-7+\-\.\/]+/
              when 10 then /[0-9+\-\.\/eE]+/
              when 16 then /[0-9a-fA-F+\-\.\/]+/
              end
      result = @scanner.scan(chars) || ''
      @col += result.length
      result
    end

    def parse_number(str, radix, exact, line, col)
      return Token.new(TOKEN_SYMBOL, SchemeSymbol.intern(str), line, col) if str.empty?

      val = if str.include?('/')
              # Rational
              parts = str.split('/')
              raise LexError, "Invalid rational: #{str}" unless parts.length == 2

              n = parts[0].to_i(radix)
              d = parts[1].to_i(radix)
              raise LexError, "Division by zero in rational: #{str}" if d.zero?

              Rational(n, d)
            elsif radix == 10 && str.match?(/[.eE]/)
              str.to_f
            else
              str.to_i(radix)
            end

      if exact == true
        val = val.rationalize if val.is_a?(Float)
      elsif exact == false
        val = val.to_f
      end

      Token.new(TOKEN_NUMBER, val, line, col)
    end

    def lex_dot_or_number(line, col)
      # Check if it's a number like .5
      if @scanner.match?(/\.[0-9]/)
        str = @scanner.scan(/\.[0-9]+([eE][+\-]?[0-9]+)?/) || '.'
        @col += str.length
        Token.new(TOKEN_NUMBER, str.to_f, line, col)
      else
        advance_char  # consume .
        # Check for ...
        if peek_char == '.' && @scanner.peek(2) == '..'
          advance_char
          advance_char
          Token.new(TOKEN_SYMBOL, SchemeSymbol.intern('...'), line, col)
        else
          Token.new(TOKEN_DOT, '.', line, col)
        end
      end
    end

    def lex_atom(line, col)
      # Scan symbol/number characters
      # Symbols can contain: a-z A-Z 0-9 ! $ % & * + - . / : < = > ? @ ^ _ ~
      str = +''
      loop do
        break if @scanner.eos?
        break if @scanner.match?(DELIMITERS)

        str << advance_char
      end

      raise LexError, "Empty atom at #{@filename}:#{line}:#{col}" if str.empty?

      # Try to parse as number
      tok = try_parse_number(str, line, col)
      return tok if tok

      # It's a symbol
      Token.new(TOKEN_SYMBOL, SchemeSymbol.intern(str), line, col)
    end

    def try_parse_number(str, line, col)
      # Integer
      if str.match?(/\A[+\-]?[0-9]+\z/)
        return Token.new(TOKEN_NUMBER, str.to_i, line, col)
      end

      # Float
      if str.match?(/\A[+\-]?[0-9]*\.[0-9]+([eE][+\-]?[0-9]+)?\z/) ||
         str.match?(/\A[+\-]?[0-9]+[eE][+\-]?[0-9]+\z/)
        return Token.new(TOKEN_NUMBER, str.to_f, line, col)
      end

      # Rational
      if str.match?(/\A[+\-]?[0-9]+\/[0-9]+\z/)
        parts = str.split('/')
        n = parts[0].to_i
        d = parts[1].to_i
        return Token.new(TOKEN_NUMBER, Rational(n, d), line, col) unless d.zero?
      end

      nil
    end
  end
end
