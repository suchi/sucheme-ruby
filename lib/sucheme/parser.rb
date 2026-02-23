# frozen_string_literal: true

module Sucheme
  class Parser
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    def self.parse(source, filename: '<string>')
      lexer = Lexer.new(source, filename: filename)
      tokens = lexer.tokenize
      new(tokens).parse_all
    end

    def parse_all
      exprs = []
      exprs << parse_expr while !at_eof?
      exprs
    end

    def parse_expr
      skip_datum_comments
      return nil if at_eof?

      tok = current_token

      case tok.type
      when TOKEN_LPAREN
        parse_list
      when TOKEN_HASH_LPAREN
        parse_vector
      when TOKEN_QUOTE
        parse_abbreviation('quote')
      when TOKEN_QUASIQUOTE
        parse_abbreviation('quasiquote')
      when TOKEN_UNQUOTE
        parse_abbreviation('unquote')
      when TOKEN_UNQUOTE_SPLICING
        parse_abbreviation('unquote-splicing')
      when TOKEN_NUMBER, TOKEN_STRING, TOKEN_BOOL, TOKEN_CHAR
        consume
        tok.value
      when TOKEN_SYMBOL
        consume
        tok.value
      when TOKEN_EOF
        raise ParseError, "Unexpected EOF"
      else
        raise ParseError, "Unexpected token: #{tok.type} at line #{tok.line}"
      end
    end

    private

    def current_token
      @tokens[@pos] || Token.new(TOKEN_EOF, nil, 0, 0)
    end

    def consume
      tok = current_token
      @pos += 1
      tok
    end

    def at_eof?
      current_token.type == TOKEN_EOF
    end

    def skip_datum_comments
      while current_token.type == TOKEN_DATUM_COMMENT
        consume  # consume #;
        parse_expr  # parse and discard next expr
        # loop to skip any additional datum comments
      end
    end

    def expect(type)
      tok = current_token
      raise ParseError, "Expected #{type} but got #{tok.type} at line #{tok.line}" unless tok.type == type

      consume
    end

    def parse_list
      tok = consume  # consume (
      line = tok.line
      elements = []
      dotted = false
      tail = nil

      loop do
        skip_datum_comments
        break if current_token.type == TOKEN_RPAREN
        raise ParseError, "Unexpected EOF in list (opened at line #{line})" if at_eof?

        if current_token.type == TOKEN_DOT
          consume  # consume .
          skip_datum_comments
          tail = parse_expr
          dotted = true
          break
        end

        elements << parse_expr
      end

      expect(TOKEN_RPAREN)

      if dotted
        # Build improper list
        Sucheme.array_to_improper_list(elements, tail)
      else
        Sucheme.array_to_list(elements)
      end
    end

    def parse_vector
      consume  # consume #(
      elements = []
      loop do
        skip_datum_comments
        break if current_token.type == TOKEN_RPAREN
        raise ParseError, "Unexpected EOF in vector" if at_eof?

        elements << parse_expr
      end
      expect(TOKEN_RPAREN)
      SchemeVector.new(elements)
    end

    def parse_abbreviation(name)
      consume  # consume abbreviation token
      expr = parse_expr
      Sucheme.array_to_list([SchemeSymbol.intern(name), expr])
    end
  end
end
