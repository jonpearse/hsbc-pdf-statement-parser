lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hsbc_pdf_statement_parser/version"

Gem::Specification.new do |spec|
  spec.name = "hsbc_pdf_statement_parser"
  spec.summary = "Quick and dirty RubyGem to parse HSBC’s statement PDFs"
  spec.license = "MIT"

  spec.authors = "Jon Pearse"
  spec.email = "hello@jonpearse.net"
  spec.homepage = "https://github.com/jonpearse/hsbc-pdf-statement-parser"

  spec.version = HsbcPdfStatementParser::VERSION
  spec.files = `git ls-files`.split($\)

  spec.add_dependency "pdf-reader", "~> 2.9"
  spec.add_dependency "dry-struct", "~> 1.4"
end
