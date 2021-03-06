module Assembler
  # Contains instruction classes and knows how to handle an instruction
  module Instructions
    instruction_list_str = %w(END HBY LBY LOD STR ADD SUB ADI
                              SBI AND ORR XOR NOT SHF BRN SPC)
    INSTRUCTION_LIST = instruction_list_str.map(&:to_sym)

    def self.instruction?(first_word_symbol)
      INSTRUCTION_LIST.include? first_word_symbol
    end

    # Basic functionality for all Instructions
    class Instruction < Command
      def word_length
        1
      end

      def machine_code(symbol_table)
        [Instructions.make_word(*nibbles(symbol_table))]
      end
    end

    # Superclass for any Instruction where
    # all its arguments must be tokenized by the Assembler::Token class
    class InstructionWithOnlyTokenArgs < Instruction
      def initialize(args_str)
        @tokens = args(args_str)
      end

      private

      def nibbles(symbol_table)
        ints = @tokens.map { |token| token.get_int(symbol_table) }
        [self.class::OP_CODE] + get_3_nibbles(*ints)
      end

      # Default implementation for instructions with 3 Token arguments
      # Override for Instruction classes with 2 Token arguments
      def get_3_nibbles(*args)
        args
      end
    end

    # Define instructions that have 3 Token arguments
    instructions_with_3_operands = [
      [:ADD, 5],
      [:SUB, 6],
      [:ADI, 7],
      [:SBI, 8],
      [:AND, 9],
      [:ORR, 10],
      [:XOR, 11]
    ]
    instructions_with_3_operands.each do |name, code|
      c = Class.new(InstructionWithOnlyTokenArgs)
      c::OP_CODE = code
      c::FORMAT = '4 4 4'
      const_set name, c
    end

    # Define instructions that have 2 Token arguments

    # get_3_nibbles for HBY and LBY instructions
    get_3_nibbles_hby_lby = lambda do |value, register|
      [value >> 4, value & 0xFF, register]
    end

    # get_3_nibbles for LOD and NOT instructions
    get_3_nibbles_lod_not =
        lambda do |source_register, destination_register|
          [source_register, 0, destination_register]
        end

    # get_3_nibbles for STR instruction
    get_3_nibbles_str = lambda do |address, register|
      [address, register, 0]
    end

    instructions_with_2_operands = [
      [:HBY, 1, get_3_nibbles_hby_lby],
      [:LBY, 2, get_3_nibbles_hby_lby],
      [:LOD, 3, get_3_nibbles_lod_not],
      [:STR, 4, get_3_nibbles_str],
      [:NOT, 0xC, get_3_nibbles_lod_not]
    ]
    instructions_with_2_operands.each do |name, code, function|
      c = Class.new(InstructionWithOnlyTokenArgs) do
        define_method(:get_3_nibbles, &function)
        private :get_3_nibbles
      end
      c::OP_CODE = code
      c::FORMAT = '8 4'
      const_set name, c
    end

    # The end program (halt) instruction
    class ENDi < Instruction
      FORMAT = '-'

      def initialize(args_str)
        args(args_str)
      end

      def nibbles(_)
        [0, 0, 0, 0]
      end
    end

    # The shift instruction
    class SHF < Instruction
      FORMAT = '4 S 4 4'

      def initialize(args_str)
        @rs1, @dir, @amount, @rd = args(args_str)
        msg = "Direction must be L or R, received: '#{@dir}'"
        fail AsmError, msg unless %w(L R).include? @dir
      end

      def nibbles(symbol_table)
        rs1 = @rs1.get_int symbol_table
        amount = @amount.get_int(symbol_table)
        msg1 = "Amount must be greater than 0, received: '#{amount}'"
        msg2 = "Amount must be less than 9, received: '#{amount}'"
        fail AsmError, msg1 if amount < 1
        fail AsmError, msg2 if amount > 8
        amount -= 1
        amount += 8 if @dir == 'R'
        rd = @rd.get_int symbol_table
        [0xD, rs1, amount, rd]
      end
    end

    # The branch instruction
    class BRN < Instruction
      def initialize(args_str)
        args = args_str.split
        @cond, value_str = condition_and_value args, args_str
        @value_register = Token.new(value_str, 4)
        @address_register = Token.new(args[-1], 4)
      end

      def nibbles(symbol_table)
        rv = @value_register.get_int symbol_table
        rp = @address_register.get_int symbol_table
        [0xE, rv, rp, @cond]
      end

      private

      def condition_and_value(args, args_str)
        case args.length
        when 3
          parse_nzp_condition_value(args)
        when 2
          parse_cv_condition_value(args)
        else
          msg = "Expected 2 or 3 arguments, received: '#{args_str}'"
          fail AsmError, msg
        end
      end

      def parse_nzp_condition_value(args)
        nzp = args[1]
        msg = 'Invalid value condition, must be combination of NZP, ' \
              "received:  '#{nzp}'"
        fail AsmError, msg unless /^[NZP]+$/ =~ nzp
        cond = 0
        cond += 4 if nzp =~ /N/
        cond += 2 if nzp =~ /Z/
        cond += 1 if nzp =~ /P/
        [cond, args[0]]
      end

      def parse_cv_condition_value(args)
        code = parse_cv_code(args[0])
        [8 | code, '0']
      end

      def parse_cv_code(cv)
        msg = 'Invalid flag condition, must be C V or -, received: ' \
              "'#{cv}'"
        case cv
        when 'V' then 2
        when 'C' then 1
        when '-' then 0
        else fail AsmError, msg
        end
      end
    end

    # The "save the program counter" instruction
    class SPC < Instruction
      FORMAT = '4'

      def initialize(args_str)
        @rs1 = args(args_str)[0]
      end

      def nibbles(symbol_table)
        rs1 = @rs1.get_int symbol_table
        [0xF, 0, 0, rs1]
      end
    end

    def self.make_word(op_code, a, b, c)
      op_code << 12 | a << 8 | b << 4 | c
    end

    def self.handle(op_code_symbol, args_str)
      # END is a reserved word; rename to ENDi
      op_code_symbol = :ENDi if op_code_symbol == :END
      const_get(op_code_symbol).new(args_str)
    end
  end
end
