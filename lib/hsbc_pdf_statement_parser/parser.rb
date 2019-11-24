class HsbcPdfStatementParser::Parser 
  
  # Creates a new parser from a PDF file.
  #
  # === Parameters
  #
  # [filename] the filename to parse
  def initialize( filename )
    
    @reader = PDF::Reader.new( filename )
    
  end
  
  # Returns an array of the transactions in the document as hashes.
  #
  # === Hash keys
  #
  # [:date] the date of the transaction _(Date)_
  # [:type] the type of the transaction, eg ‘VISA’, ‘DD’, ‘ATM’, etc _(String)_
  # [:details] the details of the transaction. This can span multiple lines _(String)_
  # [:out] the amount of the transaction, if a debit _(Float, nil)_
  # [:in] the amount of the transaction, if a credit _(Float, nil)_
  # [:change] the amount of the transacation: negative if a debit, positive if a credit _(Float)_
  def transactions
    
    @_transactions ||= begin
      
      current_transaction = nil
      current_date = nil
      transactions = []
      
      document_text
        .scan( /BALANCE\s?BROUGHT\s?FORWARD(?:.*?)\n(.*?)BALANCE\s?CARRIED\s?FORWARD/im )
        .map{ |text| parse_page( text[0] )}
        .flatten
        .each do |line|
        
          # store the current date
          current_date = line[:date] unless line[:date].nil?
        
          # if we have a type, start a new transaction
          unless line[:type].nil?
            transactions << current_transaction unless current_transaction.nil?
            current_transaction = line.merge( date: current_date )
            next
          end
        
          # merge things in
          current_transaction.merge!( line.select{ |k,v| v }, { details: "#{current_transaction[:details]}\n#{line[:details]}" })
        
        end
      
      # dump the final transaction + return
      transactions << current_transaction unless current_transaction.nil?
      transactions
    end
    
  end
  
  # Returns the opening balance of the statement read from the table on the first page.
  def opening_balance
    
    @_opening_balance ||= scan_figure( 'Opening Balance' )
    
  end
  
  # Returns the closing balance of the statement read from the table on the first page.
  def closing_balance
    
    @_closing_balance ||= scan_figure( 'Closing Balance' )
    
  end
  
  # Returns the total value of payments in during the statement read from the table on the first page (ie: not calculated)
  def payments_in
    
    @_payments_in ||= scan_figure( 'Payments In' )
    
  end
  
  # Returns the total value of payments out during the statement read from the table on the first page (ie: not calculated)
  def payments_out
    
    @_payments_out ||= scan_figure( 'Payments Out' )
    
  end
  
  private
  
  def document_text
    
    @text ||= begin
      
      @reader.pages.map( &:text ).join
      
    end
    
  end
  
  def scan_figure( search_string )
    
    @_first_page ||= @reader.pages.first.text
    
    match = Regexp.new( "#{search_string}(?:.*?)([0-9\.\,]{4,})", Regexp::IGNORECASE ).match( @_first_page )
    return nil if match.nil?
    
    match[1].gsub( ',', '' ).to_f
    
  end
  
  def parse_page( page_str )
    
    # grab lines + get the longest
    lines = page_str.lines
    max_length = lines.map( &:length ).max
    
    lines.map{ |line| parse_line( line.rstrip.ljust( max_length ))}.compact
      
  end
  
  def parse_line( line_str )
    
    # if we’re blank…
    return nil if line_str.strip.empty?
    
    # start cutting things up
    row = {
      date:    empty_to_nil( line_str[0..12] ),
      type:    empty_to_nil( line_str[12..20] ),
      details: empty_to_nil( line_str[20..70] ),
      out:     empty_to_nil( line_str[70..90] ),
      in:      empty_to_nil( line_str[90..110] ),
      balance: empty_to_nil( line_str[110..130] )
    }
    
    # munge things further
    row[:date]    = Date.strptime( row[:date], '%d %b %y' ) unless row[:date].nil?
    row[:out]     = row[:out].gsub( ',', '' ).to_f unless row[:out].nil?
    row[:in]      = row[:in].gsub( ',', '' ).to_f unless row[:in].nil?
    row[:balance] = row[:balance].gsub( ',', '' ).to_f unless row[:balance].nil?
    
    # set a change amount
    row[:change]  = if !row[:out].nil?
      0 - row[:out]
    elsif !row[:in].nil?
      row[:in]
    else
      nil
    end
    
    # return
    row
      
  end
  
  def empty_to_nil( str )
    
    ( str.strip!.empty? ) ? nil : str
    
  end
  
end