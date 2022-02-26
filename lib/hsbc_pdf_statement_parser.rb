require "bigdecimal/util"
require "date"
require "dry-struct"
require "pdf-reader"

require "hsbc_pdf_statement_parser/reader"
require "hsbc_pdf_statement_parser/statement_parser"
require "hsbc_pdf_statement_parser/transaction_parser"

module HsbcPdfStatementParser
  module Types
    include Dry.Types()
  end

  class Transaction < Dry::Struct
    attribute :date, Types::Date
    attribute :type, Types::String
    attribute :details, Types::String
    attribute :paid_out, Types::Decimal.optional
    attribute :paid_in, Types::Decimal.optional
    attribute :balance, Types::Decimal

    def change
      paid_in || 0 - paid_out
    end
  end

  class ImportedStatement < Dry::Struct
    attribute :account_holder, Types::String
    attribute :sortcode, Types::String
    attribute :account_number, Types::String

    attribute :sheets, Types::Instance(Range)
    attribute :date_range, Types::Instance(Range)

    attribute :opening_balance, Types::Decimal
    attribute :closing_balance, Types::Decimal
    attribute :payments_in, Types::Decimal
    attribute :payments_out, Types::Decimal

    attribute :transactions, Types::Array.of(Transaction)
  end

  # Parses the passed PDF file and returns an ImportedStatement
  #
  # === Parameters
  #
  # [filename] the filename to parse
  def self.parse(filename)
    StatementParser.new(filename).parse
  end
end
