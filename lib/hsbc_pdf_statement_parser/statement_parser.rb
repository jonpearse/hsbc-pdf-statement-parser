module HsbcPdfStatementParser
  class StatementParser
    attr_reader :_statement_lines

    def initialize(filename)
      @reader = Reader.new(filename)
    end

    def parse
      opening_balance = scan_figure("Opening Balance")
      closing_balance = scan_figure("Closing Balance")
      meta = get_meta

      ImportedStatement.new(
        account_holder: meta[:account_holder],
        sortcode: meta[:sortcode],
        account_number: meta[:account_no],
        sheets: meta[:sheets],
        date_range: get_date_range,
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        payments_in: scan_figure("Payments In"),
        payments_out: scan_figure("Payments Out"),
        transactions: parse_transactions(opening_balance),
      )
    end

    private def scan_figure(search_string)
      # note: I do not like how … general this regex is, but HSBC seems to love putting random noise characters into
      # opening and closing balance, so there’s only so much I can do about it.
      match = Regexp.new("#{search_string}(.*?)\n", Regexp::IGNORECASE).match(@reader.first_page)
      raise ParsingError.new("Could not find #{search_string}") if match.nil?

      match[1].strip.gsub(",", "").gsub(/\s/, "").to_d
    end

    private def get_meta
      all_meta = @reader.all_text.scan(/Account\s?Name\s+Sortcode\s+Account\s?Number\s+Sheet Number\n+([A-Z\s]+?)\s\s+([\d\-]+)\s\s+(\d+)\s\s+(\d+)\n/i)
      raise ParsingError.new("Cannot find statement metadata") if all_meta.empty?

      # check everything makes sense
      raise ParsingError.new("Error parsing account name") unless all_elements_same(all_meta.map(&:first))
      raise ParsingError.new("Error parsing sort code") unless all_elements_same(all_meta.map { |a| a[1] })
      raise ParsingError.new("Error parsing account number") unless all_elements_same(all_meta.map { |a| a[2] })

      # get page numbers
      first_page = all_meta.first[3]
      last_page = all_meta.last[3]
      raise ParsingError.new("Error parsing sheet numbers") if (first_page > last_page)

      {
        sheets: Range.new(first_page.to_i, last_page.to_i),
        account_holder: all_meta.dig(0, 0).strip,
        sortcode: all_meta.dig(0, 1).strip,
        account_no: all_meta.dig(0, 2).strip,
      }
    end

    private def get_date_range
      dates = @reader.first_page.match(/(\d{1,2}) ([a-z]+)(?: (\d{4}))? to (\d{1,2}) ([a-z]+) (\d{4})/i)
      raise ParsingError.new("Cannot find date range") unless dates
      dates = %i{start_day start_month start_year end_day end_month end_year}.zip(dates.captures).to_h

      # default the start year
      dates[:start_year] ||= dates[:end_year]
      start_date = Date.parse("#{dates[:start_day]} #{dates[:start_month]} #{dates[:start_year]}")
      end_date = Date.parse("#{dates[:end_day]} #{dates[:end_month]} #{dates[:end_year]}")
      raise ParsingError.new("Error parsing date range") if (start_date > end_date)

      Range.new(start_date, end_date)
    end

    private def parse_transactions(opening_balance)
      # Get the raw information out of the PDF text
      parser = TransactionParser.new
      transactions = parser.parse(@reader.statement_blocks)

      # start crosschecking!
      running_balance = opening_balance
      transactions.map do |tx|

        # work out what we’re doing
        running_balance += tx[:paid_in] || 0 - tx[:paid_out]

        # push a calculated balance in if none is present
        if tx[:balance].nil?
          tx[:balance] = running_balance
        else
          raise TransactionCalculationError.new(tx[:balance], running_balance) if running_balance != tx[:balance]
        end

        # all good, so create a new Transaction object
        Transaction.new(tx)
      end
    end

    private def all_elements_same(arry)
      arry.uniq.length == 1
    end
  end

  class ParsingError < StandardError
    attr_reader :info

    def initialize(message, info = nil)
      @info = info
      super(message)
    end
  end

  class TransactionCalculationError < StandardError
    attr_reader :expected, :calculated

    def initialize(expected, calculated)
      @expected = expected
      @calculated = calculated
    end

    def message
      "Expected #{@expected} but got #{@calculated}"
    end
  end
end
