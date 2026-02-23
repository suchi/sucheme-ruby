# frozen_string_literal: true

module Sucheme
  class Environment
    attr_reader :parent, :bindings

    def initialize(parent = nil)
      @parent = parent
      @bindings = {}
    end

    def lookup(name)
      name_str = name.is_a?(SchemeSymbol) ? name.name : name.to_s
      if @bindings.key?(name_str)
        @bindings[name_str]
      elsif @parent
        @parent.lookup(name)
      else
        raise UnboundVariableError, "Unbound variable: #{name_str}"
      end
    end

    def define(name, value)
      name_str = name.is_a?(SchemeSymbol) ? name.name : name.to_s
      @bindings[name_str] = value
    end

    def set!(name, value)
      name_str = name.is_a?(SchemeSymbol) ? name.name : name.to_s
      if @bindings.key?(name_str)
        @bindings[name_str] = value
      elsif @parent
        @parent.set!(name, value)
      else
        raise UnboundVariableError, "Unbound variable: #{name_str}"
      end
    end

    def defined_here?(name)
      name_str = name.is_a?(SchemeSymbol) ? name.name : name.to_s
      @bindings.key?(name_str)
    end

    # Create a child environment with given bindings
    def extend(names, values)
      child = Environment.new(self)
      names.each_with_index do |name, i|
        child.define(name, values[i])
      end
      child
    end

    def self.make_global
      env = new
      Primitives.install(env)
      env
    end
  end
end
