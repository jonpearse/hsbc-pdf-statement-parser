# HSBC PDF Statement Parser

This is a _very_ quick and dirty gem that swallows downloaded PDF files from HSBC (UK) and parses them into a [Dry::Struct](https://dry-rb.org/gems/dry-struct/1.0/) containing details of the statement + its transactions.

It exists soley because HSBC doesn’t seem to offer any way of exporting old statements as anything other than PDFs, which makes it a pain in the backside to import anything into any kind of finance packages.
You probably shouldn’t use it (see warnings below)

# Installation

Using bundler on the command line:

```shell
$ bundle add hsbc_pdf_statement_parser
$ bundle
```

## Usage

This gem exposes one method: `parse`, which takes the path to a statement PDF and returns a `Dry::Struct` representation.

```ruby
require 'hsbc_pdf_statement_parser'

parsed = HsbcPdfStatementParser.parse( 'path/to/statement.pdf' )
parsed.transactions.each do |tx|
  printf( 
    "[%s] {%-3s} %-40s %7.02f  |  %7.02f\n", 
    tx.date, 
    tx.type,
    tx.details.lines.first.strip, 
    tx.change,
    tx.balance
  )
end
```

### Statement Properties

- `account_holder`: the name of the account holder _(String)_
- `sortcode`: the sortcode shown on the statement _(String)_
- `account_number`: the account number shown on the statement _(String)_
- `sheets`: the sheets used in the statement _(Range[Int])_
- `date_range`: the date range shown on the first page of the statement _(Range[Date])_
- `opening_balance`: the opening balance of the statement _(Decimal)_
- `closing_balance`: the closing balance of the statement _(Decimal)_
- `payments_in`: the total of all transactions into the account _(Decimal)_
- `payments_out`: the total of all transactions out of the account _(Decimal)_

**Note:** `payments_in` and `payments_out` are those shown on the first page of the statement and they are not calculated from- or checked against the parsed transactions.

Also note that sheet numbers are not guaranteed to be unique. Not sure why this is the case, but I have a few statements where the the last sheet of one statement and the first of another have the same sheet number.

### Transaction Properties

- `date`: the date of the transaction _(Date)_
- `type`: a string representation of the type of the transaction (eg. `DD` for a direct debit, `VIS` for VISA, etc) _(String)_
- `details`: a text description of the transaction, which may span multiple lines _(String)_
- `paid_in`: the amount paid in, if appropriate _(Decimal, nullable)_
- `paid_out`: the amount paid out, if appropriate _(Decimal, nullable)_
- `balance`: the balance of the account after the transaction _(Decimal)_
- `change`: the calculated change to the balance of the account: negative for debits, positive for credits _(Decimal)_

**Note:** unlike in V1, `balance` is now always present and is calculated as a running total based on the opening balance of the statement. Where the statement shows a running balance after transactions (seems to be once a day), this is checked and the parser will raise an error if any discrepancy is found.

## ⚠️ Warnings

This gem has been thrown together for my own needs, and is offered to the world just in case someone else might want to play around with it. 
It seems to work pretty well with statements from my Advance account here in the UK, and may also work with other flavours of accounts from elsewhere in the world, but comes with absolutely zero guarantees or assurances.

That is to say: it seems to work OK for mucking around, but I’d recommend not using it for anything mission-critical, or in a situation that might lead you or others into making any kind of financial decisions.
Any dumb financial decisions made are entirely on you =)

### Wot? No tests

I have plenty, sadly the only way of properly testing this code is by parsing real bank statements, and I’m not about to commit any of those to github. Sorry!

## Upgrading from V1.x

For various reasons I’ve not worried too much about trying to maintain backward compatibility: migration should be relatively minimal, though:

### Breaking changes

1. invocation: `HsbcPdfStatementParser::Parser.new(…)` becomes `HsbcPdfStatementParser.parse(…)`
2. when using parsed transactions, `in` and `out` are now `paid_in` and `paid_out` respectively
3. any use of `fetch(…)` on parsed transactions will need to be replaced with bare function calls (hash accessors—ie `tx[:date]`—will continue to work)

### Nonbreaking changes

Aside from the new properties added to the main Statement type, the biggest difference is that a statement’s `balance` property is now always specified, whereas it was only specified once a day in V1.x

---

Share and enjoy