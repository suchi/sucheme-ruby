# frozen_string_literal: true

module Sucheme
  # Represents Scheme's empty list ()
  class SchemeNull
    include Comparable

    INSTANCE = new

    def self.instance
      INSTANCE
    end

    def to_s
      '()'
    end

    def inspect
      '()'
    end

    def null?
      true
    end

    def ==(other)
      other.is_a?(SchemeNull)
    end
  end

  NULL = SchemeNull::INSTANCE

  # Represents a Scheme pair (cons cell)
  class SchemePair
    attr_accessor :car, :cdr

    def initialize(car, cdr)
      @car = car
      @cdr = cdr
    end

    def to_s
      "(#{pair_to_s})"
    end

    def inspect
      to_s
    end

    def ==(other)
      return false unless other.is_a?(SchemePair)

      car == other.car && cdr == other.cdr
    end

    # Convert to Ruby array (only for proper lists)
    def to_a
      result = []
      current = self
      while current.is_a?(SchemePair)
        result << current.car
        current = current.cdr
      end
      raise TypeError, "Not a proper list: #{self}" unless current.is_a?(SchemeNull)

      result
    end

    def proper_list?
      current = self
      current = current.cdr while current.is_a?(SchemePair)
      current.is_a?(SchemeNull)
    end

    def length
      count = 0
      current = self
      while current.is_a?(SchemePair)
        count += 1
        current = current.cdr
      end
      raise TypeError, "Not a proper list" unless current.is_a?(SchemeNull)

      count
    end

    private

    def pair_to_s
      result = scheme_write(car)
      case cdr
      when SchemeNull
        result
      when SchemePair
        "#{result} #{cdr.send(:pair_to_s)}"
      else
        "#{result} . #{scheme_write(cdr)}"
      end
    end

    def scheme_write(obj)
      case obj
      when String
        "\"#{Sucheme.escape_string(obj)}\""
      when SchemeChar
        obj.write_repr
      else
        obj.to_s
      end
    end
  end

  # Represents a Scheme symbol
  class SchemeSymbol
    attr_reader :name

    INTERNED = {}

    def self.intern(name)
      INTERNED[name] ||= new(name)
    end

    def initialize(name)
      @name = name
    end

    def to_s
      @name
    end

    def inspect
      @name
    end

    def ==(other)
      other.is_a?(SchemeSymbol) && @name == other.name
    end

    def eql?(other)
      self == other
    end

    def hash
      @name.hash
    end
  end

  # Represents a Scheme character
  class SchemeChar
    attr_reader :char

    def initialize(char)
      @char = char
    end

    def to_s
      @char
    end

    def inspect
      write_repr
    end

    def write_repr
      case @char
      when ' '  then '#\space'
      when "\n" then '#\newline'
      when "\t" then '#\tab'
      when "\r" then '#\return'
      when "\0" then '#\nul'
      when "\e" then '#\escape'
      when "\x7f" then '#\delete'
      when "\b" then '#\backspace'
      when "\f" then '#\page'
      else "#\\#{@char}"
      end
    end

    def ==(other)
      other.is_a?(SchemeChar) && @char == other.char
    end

    def eql?(other)
      self == other
    end

    def hash
      @char.hash
    end
  end

  # Represents a Scheme vector
  class SchemeVector
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def [](idx)
      @data[idx]
    end

    def []=(idx, val)
      @data[idx] = val
    end

    def length
      @data.length
    end

    def to_s
      "#(#{@data.map { |e| scheme_write(e) }.join(' ')})"
    end

    def inspect
      to_s
    end

    def ==(other)
      other.is_a?(SchemeVector) && @data == other.data
    end

    private

    def scheme_write(obj)
      case obj
      when String
        "\"#{Sucheme.escape_string(obj)}\""
      when SchemeChar
        obj.write_repr
      else
        obj.to_s
      end
    end
  end

  # Represents a Scheme procedure (lambda/closure)
  class SchemeProcedure
    attr_reader :params, :body, :env, :rest_param
    attr_accessor :name

    def initialize(params, body, env, name: nil)
      @name = name
      @body = body
      @env = env
      # Handle rest parameter (dotted pair params)
      if params.is_a?(SchemeSymbol)
        @params = []
        @rest_param = params
      elsif params.is_a?(SchemePair)
        @params = []
        @rest_param = nil
        current = params
        while current.is_a?(SchemePair)
          @params << current.car
          current = current.cdr
        end
        @rest_param = current unless current.is_a?(SchemeNull)
      else
        @params = []
        @rest_param = nil
      end
    end

    def to_s
      name_part = @name ? " #{@name}" : ''
      "#<procedure#{name_part}>"
    end

    def inspect
      to_s
    end

    def variadic?
      !@rest_param.nil?
    end
  end

  # Represents a built-in primitive procedure
  class SchemePrimitive
    attr_reader :name, :proc

    def initialize(name, &block)
      @name = name
      @proc = block
    end

    def call(*args)
      @proc.call(*args)
    end

    def to_s
      "#<primitive #{@name}>"
    end

    def inspect
      to_s
    end
  end

  # Represents a syntax-rules macro
  class SchemeMacro
    attr_reader :name, :literals, :rules

    def initialize(name, literals, rules)
      @name = name
      @literals = literals
      @rules = rules
    end

    def to_s
      "#<macro #{@name}>"
    end

    def inspect
      to_s
    end
  end

  # Represents the unspecified/void value
  class SchemeVoid
    INSTANCE = new

    def self.instance
      INSTANCE
    end

    def to_s
      ''
    end

    def inspect
      '#<void>'
    end

    def void?
      true
    end
  end

  VOID = SchemeVoid::INSTANCE

  # Represents a tail call thunk for TCO
  class SchemeTailCall
    attr_reader :expr, :env

    def initialize(expr, env)
      @expr = expr
      @env = env
    end
  end

  # Represents a promise (delay/force)
  class SchemePromise
    attr_reader :thunk
    attr_accessor :forced, :value

    def initialize(thunk)
      @thunk = thunk
      @forced = false
      @value = nil
    end

    def to_s
      "#<promise #{@forced ? 'forced' : 'unforced'}>"
    end

    def inspect
      to_s
    end
  end

  # Represents an I/O port
  class SchemePort
    attr_reader :io, :mode

    def initialize(io, mode)
      @io = io
      @mode = mode # :input or :output
      @closed = false
    end

    def input?
      @mode == :input
    end

    def output?
      @mode == :output
    end

    def closed?
      @closed
    end

    def close
      @io.close unless @io == $stdin || @io == $stdout || @io == $stderr
      @closed = true
    end

    def to_s
      "#<#{@mode}-port>"
    end

    def inspect
      to_s
    end
  end

  # Represents a string port
  class SchemeStringPort < SchemePort
    def initialize(str, mode)
      if mode == :input
        super(StringIO.new(str), mode)
      else
        sio = StringIO.new
        super(sio, mode)
      end
    end

    def get_output_string
      @io.string
    end
  end

  # Represents EOF object
  class SchemeEof
    INSTANCE = new

    def self.instance
      INSTANCE
    end

    def to_s
      '#<eof>'
    end

    def inspect
      to_s
    end
  end

  EOF_OBJECT = SchemeEof::INSTANCE

  # Represents a continuation
  class SchemeContinuation
    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    def to_s
      '#<continuation>'
    end

    def inspect
      to_s
    end
  end

  # Represents multiple values
  class SchemeValues
    attr_reader :values

    def initialize(values)
      @values = values
    end

    def to_s
      @values.map { |v| scheme_display(v) }.join("\n")
    end

    private

    def scheme_display(obj)
      case obj
      when String then obj
      else obj.to_s
      end
    end
  end

  # Represents a dynamic parameter
  class SchemeParameter
    attr_accessor :value

    def initialize(value, converter = nil)
      @value = value
      @converter = converter
      @stack = []
    end

    def push(val)
      new_val = @converter ? @converter.call(val) : val
      @stack.push(@value)
      @value = new_val
    end

    def pop
      @value = @stack.pop
    end

    def to_s
      '#<parameter>'
    end

    def inspect
      to_s
    end
  end

  # Shared string escaping helper
  def self.escape_string(str)
    str.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\t", '\\t').gsub("\r", '\\r')
  end

  # Build list from Ruby array
  def self.array_to_list(arr)
    result = NULL
    arr.reverse_each { |e| result = SchemePair.new(e, result) }
    result
  end

  # Build improper list with dotted tail
  def self.array_to_improper_list(arr, tail)
    result = tail
    arr.reverse_each { |e| result = SchemePair.new(e, result) }
    result
  end
end
