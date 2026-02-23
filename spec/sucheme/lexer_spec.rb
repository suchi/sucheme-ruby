# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sucheme::Lexer do
  def tokenize(source)
    lexer = described_class.new(source)
    lexer.tokenize.reject { |t| t.type == Sucheme::TOKEN_EOF }
  end

  def token_types(source)
    tokenize(source).map(&:type)
  end

  def token_values(source)
    tokenize(source).map(&:value)
  end

  describe 'integers' do
    it 'tokenizes positive integer' do
      expect(token_values('42')).to eq([42])
    end

    it 'tokenizes negative integer' do
      expect(token_values('-7')).to eq([-7])
    end

    it 'tokenizes zero' do
      expect(token_values('0')).to eq([0])
    end
  end

  describe 'floats' do
    it 'tokenizes float' do
      expect(token_values('3.14')).to eq([3.14])
    end

    it 'tokenizes negative float' do
      expect(token_values('-2.5')).to eq([-2.5])
    end

    it 'tokenizes scientific notation' do
      expect(token_values('1e5')).to eq([1e5])
    end
  end

  describe 'rationals' do
    it 'tokenizes rational' do
      tok = tokenize('1/2')
      expect(tok.length).to eq(1)
      expect(tok[0].value).to eq(Rational(1, 2))
    end
  end

  describe 'radix prefixes' do
    it 'tokenizes hex' do
      expect(token_values('#xff')).to eq([255])
    end

    it 'tokenizes binary' do
      expect(token_values('#b1010')).to eq([10])
    end

    it 'tokenizes octal' do
      expect(token_values('#o17')).to eq([15])
    end
  end

  describe 'exactness' do
    it 'tokenizes #e (exact)' do
      result = token_values('#e1.5')
      expect(result[0]).to be_a(Rational)
      expect(result[0]).to eq(Rational(3, 2))
    end

    it 'tokenizes #i (inexact)' do
      result = token_values('#i3')
      expect(result[0]).to be_a(Float)
      expect(result[0]).to eq(3.0)
    end
  end

  describe 'booleans' do
    it 'tokenizes #t' do
      expect(token_values('#t')).to eq([true])
    end

    it 'tokenizes #f' do
      expect(token_values('#f')).to eq([false])
    end

    it 'tokenizes #true' do
      expect(token_values('#true')).to eq([true])
    end

    it 'tokenizes #false' do
      expect(token_values('#false')).to eq([false])
    end
  end

  describe 'strings' do
    it 'tokenizes simple string' do
      expect(token_values('"hello"')).to eq(['hello'])
    end

    it 'handles escape sequences' do
      expect(token_values('"a\\nb"')).to eq(["a\nb"])
    end

    it 'handles tab escape' do
      expect(token_values('"a\\tb"')).to eq(["a\tb"])
    end

    it 'handles backslash escape' do
      expect(token_values('"a\\\\b"')).to eq(['a\\b'])
    end

    it 'handles quote escape' do
      expect(token_values('"a\\"b"')).to eq(['a"b'])
    end
  end

  describe 'characters' do
    it 'tokenizes #\\a' do
      result = token_values('#\a')
      expect(result[0]).to be_a(Sucheme::SchemeChar)
      expect(result[0].char).to eq('a')
    end

    it 'tokenizes #\\space' do
      result = token_values('#\space')
      expect(result[0].char).to eq(' ')
    end

    it 'tokenizes #\\newline' do
      result = token_values('#\newline')
      expect(result[0].char).to eq("\n")
    end

    it 'tokenizes #\\tab' do
      result = token_values('#\tab')
      expect(result[0].char).to eq("\t")
    end
  end

  describe 'symbols' do
    it 'tokenizes simple symbol' do
      result = token_values('foo')
      expect(result[0]).to be_a(Sucheme::SchemeSymbol)
      expect(result[0].name).to eq('foo')
    end

    it 'tokenizes +' do
      result = token_values('+')
      expect(result[0].name).to eq('+')
    end

    it 'tokenizes ...' do
      result = token_values('...')
      expect(result[0].name).to eq('...')
    end

    it 'tokenizes symbol with special chars' do
      result = token_values('string->number')
      expect(result[0].name).to eq('string->number')
    end
  end

  describe 'parentheses and structure' do
    it 'tokenizes open paren' do
      expect(token_types('(')).to eq([Sucheme::TOKEN_LPAREN])
    end

    it 'tokenizes close paren' do
      expect(token_types(')')).to eq([Sucheme::TOKEN_RPAREN])
    end

    it 'tokenizes #(' do
      expect(token_types('#(')).to eq([Sucheme::TOKEN_HASH_LPAREN])
    end

    it 'tokenizes dot' do
      expect(token_types('.')).to eq([Sucheme::TOKEN_DOT])
    end

    it 'tokenizes quote' do
      expect(token_types("'")).to eq([Sucheme::TOKEN_QUOTE])
    end

    it 'tokenizes quasiquote' do
      expect(token_types('`')).to eq([Sucheme::TOKEN_QUASIQUOTE])
    end

    it 'tokenizes unquote' do
      expect(token_types(',')).to eq([Sucheme::TOKEN_UNQUOTE])
    end

    it 'tokenizes unquote-splicing' do
      expect(token_types(',@')).to eq([Sucheme::TOKEN_UNQUOTE_SPLICING])
    end
  end

  describe 'comments' do
    it 'ignores line comments' do
      expect(token_values("; comment\n42")).to eq([42])
    end

    it 'ignores block comments' do
      expect(token_values('#| block |# 42')).to eq([42])
    end

    it 'handles datum comments' do
      result = token_types('#; 42 hello')
      expect(result).to include(Sucheme::TOKEN_DATUM_COMMENT)
    end
  end

  describe 'multiple tokens' do
    it 'tokenizes a list' do
      types = token_types('(+ 1 2)')
      expect(types).to eq([
        Sucheme::TOKEN_LPAREN,
        Sucheme::TOKEN_SYMBOL,
        Sucheme::TOKEN_NUMBER,
        Sucheme::TOKEN_NUMBER,
        Sucheme::TOKEN_RPAREN
      ])
    end
  end
end
