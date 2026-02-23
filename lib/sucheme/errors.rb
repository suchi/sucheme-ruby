# frozen_string_literal: true

module Sucheme
  class SuchemeError < StandardError; end
  class LexError < SuchemeError; end
  class ParseError < SuchemeError; end
  class EvalError < SuchemeError; end
  class ArityError < EvalError; end
  class TypeError < EvalError; end
  class UnboundVariableError < EvalError; end
end
