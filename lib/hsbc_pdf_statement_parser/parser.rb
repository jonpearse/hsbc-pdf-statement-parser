class HsbcPdfStatementParser::Parser 
      
  def initialize( filename )
    
    reader = PDF::Reader.new( filename )
    
    @buff = []
    reader.pages.each do |page|
            
      page_match = page.text.match( /BALANCE\s?BROUGHT\s?FORWARD(?:.*?)\n(.*?)BALANCE\s?CARRIED\s?FORWARD/im )
      next if page_match.nil?

      @buff += parse_page( page_match[1] )
      
    end
    
  end
  
  def transactions
    
    @_transactions ||= begin
  
      current_transaction = nil
      current_date = nil
      
      retval = []
      
      @buff.each do |line|
        
        # store the current date
        current_date = line[:date] unless line[:date].nil?
        
        # if we have a type, start a new transaction
        unless line[:type].nil?
          retval << current_transaction unless current_transaction.nil?
          current_transaction = line.merge( date: current_date )
          next
        end
        
        # merge things in
        current_transaction.merge!( line.select{ |k,v| v }, { details: "#{current_transaction[:details]}\n#{line[:details]}" })
        
      end
      
      # dump the final transaction + return    
      retval << current_transaction unless current_transaction.nil?
      retval
      
    end
    
  end
  
  private
  
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