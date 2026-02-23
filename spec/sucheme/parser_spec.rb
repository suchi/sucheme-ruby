# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sucheme::Parser do
  def parse(source)
    described_class.parse(source)
  end

  def parse1(source)
    parse(source)[0]
  end

  describe 'atoms' do
    it 'parses integer' do
      expect(parse1('42')).to eq(42)
    end

    it 'parses symbol' do
      result = parse1('foo')
      expect(result).to be_a(Sucheme::SchemeSymbol)
      expect(result.name).to eq('foo')
    end

    it 'parses string' do
      expect(parse1('"hello"')).to eq('hello')
    end

    it 'parses boolean true' do
      expect(parse1('#t')).to eq(true)
    end

    it 'parses boolean false' do
      expect(parse1('#f')).to eq(false)
    end

    it 'parses character' do
      result = parse1('#\a')
      expect(result).to be_a(Sucheme::SchemeChar)
      expect(result.char).to eq('a')
    end
  end

  describe 'lists' do
    it 'parses empty list' do
      result = parse1('()')
      expect(result).to be_a(Sucheme::SchemeNull)
    end

    it 'parses simple list' do
      result = parse1('(1 2 3)')
      expect(result).to be_a(Sucheme::SchemePair)
      expect(result.car).to eq(1)
      expect(result.cdr.car).to eq(2)
      expect(result.cdr.cdr.car).to eq(3)
    end

    it 'parses nested list' do
      result = parse1('(1 (2 3) 4)')
      expect(result.car).to eq(1)
      inner = result.cdr.car
      expect(inner).to be_a(Sucheme::SchemePair)
      expect(inner.car).to eq(2)
    end

    it 'parses dotted pair' do
      result = parse1('(1 . 2)')
      expect(result).to be_a(Sucheme::SchemePair)
      expect(result.car).to eq(1)
      expect(result.cdr).to eq(2)
    end

    it 'parses improper list' do
      result = parse1('(1 2 . 3)')
      expect(result.car).to eq(1)
      expect(result.cdr.car).to eq(2)
      expect(result.cdr.cdr).to eq(3)
    end
  end

  describe 'vectors' do
    it 'parses vector' do
      result = parse1('#(1 2 3)')
      expect(result).to be_a(Sucheme::SchemeVector)
      expect(result[0]).to eq(1)
      expect(result[1]).to eq(2)
      expect(result[2]).to eq(3)
    end

    it 'parses empty vector' do
      result = parse1('#()')
      expect(result).to be_a(Sucheme::SchemeVector)
      expect(result.length).to eq(0)
    end
  end

  describe 'quote abbreviations' do
    it "parses 'x as (quote x)" do
      result = parse1("'foo")
      expect(result).to be_a(Sucheme::SchemePair)
      expect(result.car.name).to eq('quote')
      expect(result.cdr.car.name).to eq('foo')
    end

    it 'parses `x as (quasiquote x)' do
      result = parse1('`foo')
      expect(result.car.name).to eq('quasiquote')
    end

    it 'parses ,x as (unquote x)' do
      result = parse1(',foo')
      expect(result.car.name).to eq('unquote')
    end

    it 'parses ,@x as (unquote-splicing x)' do
      result = parse1(',@foo')
      expect(result.car.name).to eq('unquote-splicing')
    end
  end

  describe 'datum comments' do
    it 'skips datum-commented expressions' do
      result = parse('1 #; 2 3')
      expect(result.length).to eq(2)
      expect(result[0]).to eq(1)
      expect(result[1]).to eq(3)
    end
  end

  describe 'multiple expressions' do
    it 'parses multiple top-level expressions' do
      result = parse('1 2 3')
      expect(result.length).to eq(3)
    end
  end

  describe 'error handling' do
    it 'raises ParseError on unmatched paren' do
      expect { parse('(1 2') }.to raise_error(Sucheme::ParseError)
    end
  end
end
