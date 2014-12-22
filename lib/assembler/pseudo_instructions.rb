module Assembler
  # Contains pseudo-instruction classes and knows how to handle a
  # pseudo-instruction
  module PseudoInstructions
    PSEUDO_INSTRUCTIONS_LIST = [:CPY, :NOP, :WRD, :INC, :DEC, :JMP]

    def self.pseudo_instruction?(first_word)
      PSEUDO_INSTRUCTIONS_LIST.include? first_word
    end
    # Copy pseudo-instruction:  copy value from one register to another
    class CPY < Instructions::ADI
      def initialize(args_str)
        source, destination = args_str.split
        super("#{source} 0 #{destination}")
      end
    end

    # Sets register to 16-bit value using HBY + LBY instruction sequence
    # Example:    WRD $1234 R7    ==>    HBY $12 R7    LBY $34 R7
    class WRD < Command
      def initialize(args_str)
        # get value, store for later
        value_str, register = args_str.split
        @value = Token.new value_str
        @register = Token.new register
        @word_length = 2
      end

      def machine_code(symbol_table)
        value = @value.get_int symbol_table
        high_byte = value >> 8
        low_byte = value & 0x00FF
        rd = @register.get_int symbol_table
        [1 << 12 | high_byte << 4 | rd, 2 << 12 | low_byte << 4 | rd]
      end
    end

    inc_dec_str = '%{args_str} 1 %{args_str}'

    class_data = [
      [:NOP, :ADI, '0 0 0'],          # ADI R0 0 R0   ---  R0 + 0 => R0
      [:INC, :ADI, inc_dec_str],
      [:DEC, :SBI, inc_dec_str],
      [:JMP, :BRN, '0 NZP %{args_str}']
    ]

    class_data.each do |name, super_class, args_str_template|
      c = Class.new(Instructions.const_get(super_class)) do
        define_method(:initialize) do |args_str|
          super(args_str_template % { args_str: args_str })
        end
      end
      const_set name, c
    end

    def self.handle(op_code_symbol, args_str)
      const_get(op_code_symbol).new(args_str)
    end
  end
end
