#! /usr/bin/env ruby


module Assembler


  class AsmError < StandardError
  end


  class Token
    attr_reader :type, :value

    def initialize(str)
      if ['$', '%', /\d/].any? {|match| match === str[0]}
        @type = :int
        @value = Assembler.to_int str
      else
        @type = :symbol
        @value = str.to_sym
        # could check for invalid symbols
      end
    end
  end


  class Assembly
    attr_reader :line_number

    def initialize(lines)
      @line_number = 0
      @lines = lines
    end

    def peek_line
      @lines[0]
    end

    def pop_line
      @line_number += 1
      @lines.shift
    end

    def empty?
      @lines.empty?
    end

  end


  class CommandList
    attr_reader :word_index

    def initialize()
      # The index of the next free address
      @word_index = 0
      @commands = []
    end

    def add_command(cmd)
      inc_words cmd.word_length
    end

    def inc_words(n)
      @word_index += n
    end

    def word_length
      @word_index
    end

  end


  def self.main
    usage = "Usage:  ./assembler.rb path/to/file.asm > path/to/file.exe"
    if ARGV.length != 1
      puts usage
      exit
    end
    lines = File.readlines(ARGV[0]).to_a
    asm = Assembly.new lines
    commands = CommandList.new
    symbol_table = make_symbol_table
    new_lines = []
    # can't use each_with_index since the line_number and word_index can
    # change by a variable # based on the command
    until asm.empty?
      line = strip(asm.pop_line)
      if line.empty?
        next
      end
      first_word, args_str = line.split(/\s+/, 2)
      type = line_type first_word
      case type
      when :label then
        label(first_word, symbol_table, commands.word_index)
      when :set_directive then
        set_directive(args_str, symbol_table)
      when :include_directive then
        include_directive(args_str)
      when :command then
        handle_command(first_word, args_str, commands)
      end
      new_lines.push line
    end
    puts new_lines
    symbol_table.each {|k, v| puts "  #{k.to_s.rjust(11)} => #{v}"}
  end


  def self.strip(line)
    new_line = line.strip
    if new_line.empty? or new_line[0] == '#'
      return ''
    end
    first_word, rest = new_line.split(' ', 2)
    if first_word == '.string'
      return new_line
    end
    new_line.split('#', 2)[0].strip
  end


  def self.make_symbol_table
    st = {
      :sound => 0xD800,
      :"net-in" => 0xDC00,
      :"net-out" => 0xE000,
      :"storage-in" => 0xE400,
      :"storage-out" => 0xE800,
      :tiles => 0xEC00,
      :grid => 0xF400,
      :"cell-x-y-flip" => 0xFD60,
      :sprites => 0xFE8C,
      :"cell-colors" => 0xFF8C,
      :"sprite-colors" => 0xFFAC,
      :keyboard => 0xFFFA,
      :"net-status" => 0xFFFB,
      :"enable-bits" => 0xFFFC,
      :"storage-read-address" => 0xFFFD,
      :"storage-write-address" => 0xFFFE,
      :"frame-interrupt-vector" => 0xFFFF,
    }
    (0...16).each do |i|
      st[("R" + i.to_s).to_sym] = i
    end
    ('A'..'F').each_with_index do |c, i|
      st[("R" + c).to_sym] = i + 10
    end
    st
  end


  def self.to_int(str)
    if /^\d[x|X]/ === str[0..1]
      raise AsmError.new, "Malformed integer"
    end
    start, base = case str[0]
                  when "%" then [1, 2]
                  when "$" then [1, 16]
                  else [0, 10]
                  end
    num = begin
            Integer(str[start..-1], base)
          rescue ArgumentError
            raise AsmError.new, "Malformed integer"
          end
    if num > 0xFFFF
      raise AsmError.new, "Number greater than $FFFF"
    end
    num
  end

  def self.line_type(first_word)
    if first_word[0] == '('
      :label
    elsif first_word == '.set'
      :set_directive
    elsif first_word == '.include'
      :include_directive
    else
      :command
    end
  end

  def self.label(first_word, symbol_table, word_index)
    symbol_table[first_word[1...-1].to_sym] = word_index
  end

  def self.set_directive(args_str, symbol_table)
    name, str_value = args_str.split(/\s+/, 2)
    token = Token.new str_value
    value = if token.type == :symbol
              symbol_table[token.value]
            else
              token.value
            end
    symbol_table[name] = value
  end

  def self.include_directive(args_str)
  end

  def self.handle_command(first_word, args_str, commands)
  end

end


if __FILE__ == $0
  Assembler.main()
end
