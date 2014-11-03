module Assembler::Directives

  def self.directive_to_class_name(symbol)
    symbol[1..-1].split('-').map(&:capitalize).push('Directive').join.to_sym
  end

  class MoveDirective < Assembler::Command
    def initialize(args_str, asm, word_index, symbol_table)
      address_token = Assembler::Token.new args_str
      address = address_token.get_int symbol_table
      @word_length = address - word_index
    end

    def machine_code(symbol_table)
      (0...@word_length).map { 0x0000 }
    end
  end

  class WordDirective < Assembler::Command
    def initialize(args_str, asm, word_index, symbol_table)
      super()
    end
  end

  class ArrayDirective < Assembler::Command
    def initialize(args_str, asm, word_index, symbol_table)
      super()
    end
  end

  def self.handle(directive_symbol, args_str, asm, word_index, symbol_table)
    class_name = directive_to_class_name directive_symbol
    const_get(class_name).new(args_str, asm, word_index, symbol_table)
  end

end
