# This is a horrendous patch to work around issue #169 in the pdf-reader repo (https://github.com/yob/pdf-reader/issues/169).
#
# Short version is that whatever HSBC is using to generate PDFs doesn’t seem to null-/whitespace-terminate inline image
# data. Thus, when PdfReader tries to find the ‘EI’ token when parsing inline media, it can’t and simply runs off the end
# of the document, causing a TypeError to be thrown.
#
# The PDF files I’m getting all seem to end some of the images with xE0, so I’ve simply monkey-patched this into the
# library for use with my files.
# This may not be the case for anyone else, in which case maybe add whatever your problem character is to the regex and
# open a PR should you feel the need.
# 
# Or, y’know, look at the PdfReader source and see if you can work out something better, because this is horrendous :/

module PdfReaderPatch
  def self.included( base )
    base.class_eval do      
      def prepare_inline_token
        str = "".dup

        buffer = []
        to_rewind = -3

        until buffer[0] =~ /\s|\0|\xE0/n && buffer[1, 2] == ['E', 'I']
          chr = @io.read(1)
          buffer << chr
          
          if buffer.length > 3
            str << buffer.shift
          end
          
          to_rewind = -2 if buffer.first =~ /\xE0/n
        end

        str << '\0' if buffer.first == '\0'

        @tokens << string_token(str)
              
        @io.seek(to_rewind, IO::SEEK_CUR) unless chr.nil?      
      end
    end
  end
end

PDF::Reader::Buffer.send( :include, PdfReaderPatch )