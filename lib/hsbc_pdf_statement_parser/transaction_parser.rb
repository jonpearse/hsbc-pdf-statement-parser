require "bigdecimal/util"
require "date"

module HsbcPdfStatementParser
  class TransactionParser
    attr_reader :transactions

    def parse(input)
      # We need to parse pages individually because the column widths may not be the same on each page
      parsed_lines = input.reduce([]) { |lines, page| lines + parse_page(page) }

      # build out transactions from our parsed data
      @transactions = parse_transactions(parsed_lines)
    end

    private def parse_page(page_data)
      # get the maximum line length for this page
      max_line_length = page_data.lines.map(&:length).max

      # work out the columns being used
      column_indices = find_columns(page_data, max_line_length)

      # get the column keys and produce a map for parsing
      column_keys = get_column_keys(column_indices, max_line_length)
      column_map = column_keys.zip(column_indices).to_h

      # parse out all the
      page_data.lines.reduce([]) do |parsed, line|
        next parsed if line.strip.empty?

        parsed << parse_line(line, column_map, max_line_length)
      end
    end

    private def find_columns(input, max_line_length)
      state = Array.new(max_line_length, " ")

      # scan the content + look for obvious columns
      input.lines.each do |line|
        # bounce if there’s no point…
        next if line.strip.empty?

        # map the state
        line.split("").each.with_index { |chr, i| state[i] = "X" if chr != " " }
      end

      # We will almost have something like XX XXX XX for the date column, so replace any spaces with an X either side
      # with an X
      state = state.join.gsub(/X X/, "XXX")

      # find the columns
      columns = []
      state.gsub(/X+/) { columns << Range.new(*$~.offset(0)) }
      columns
    end

    private def get_column_keys(indices, max_line_length)
      # if we have 6 columns, we’re all good…
      return %i{date type details paid_out paid_in balance} if indices.length == 6

      # if a statement contains no payments in or no payments out, it’ll only have 5 columns, so we need to work out
      # which the additional column is
      # We can do this with an assumption that the ‘paid out’ column is usually at around 2/3 of the total line length…
      has_paid_out = indices.map { |i| i.first.to_f / max_line_length }.any? { |p| p > 0.6 && p < 0.7 }
      additional = has_paid_out ? :paid_out : :paid_in

      [:date, :type, :details, additional, :balance]
    end

    private def parse_line(line, map, max_line_length)
      # lengthen the line
      line = line.rstrip.ljust(max_line_length)

      # cut things up
      row = {
        paid_out: nil,
        paid_in: nil,
      }
      map.each { |k, v| row[k] = empty_to_nil(line[v]) }

      # further processing
      row[:date] = Date.strptime(row[:date], "%d %b %y") unless row[:date].nil?
      row[:paid_out] = parse_decimal(row[:paid_out])
      row[:paid_in] = parse_decimal(row[:paid_in])
      row[:balance] = parse_decimal(row[:balance])

      row
    end

    private def parse_decimal(str)
      return nil if str.nil?

      mult = str.end_with?("D") ? -1 : 1

      str.gsub(",", "").to_d * mult
    end

    private def empty_to_nil(str)
      str = str.strip

      str.empty? ? nil : str
    end

    private def parse_transactions(parsed_lines)
      current_date = nil
      current_transaction = nil

      transactions = []

      parsed_lines.each do |parsed|
        # if we have a new date, store it
        current_date = parsed[:date] unless parsed[:date].nil?

        # if we have a type, it’s a new transaction, so push any existing info onto the list + reset
        unless parsed[:type].nil?
          transactions << current_transaction unless current_transaction.nil?
          current_transaction = parsed.merge(date: current_date)
          next
        end

        # otherwise, merge things together
        current_transaction = current_transaction.merge(
          parsed.reject { |_, v| v.nil? },
          { details: "#{current_transaction[:details]}\n#{parsed[:details]}".strip }
        )
      end

      # shove the last transaction onto the list + return
      transactions << current_transaction
      transactions
    end
  end
end
