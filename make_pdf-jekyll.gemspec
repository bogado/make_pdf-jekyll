Gem::Specification.new do |s|
  s.name        = "make_pdf-jekyll"
  s.version     = "0.0.1"
  s.summary     = "Create PDF along side of HTML files for site."
  s.description = "Allows that some documents, or pages to have a pdf version pre generated."
  s.authors     = ["Victor Bogado da Silva Lins"]
  s.email       = "victor@bogado.net  "
  s.files       = [
    "lib/make_pdf/jekyll.rb",
    "lib/make_pdf.rb",
    "lib/make_pdf/Chrome.rb",
    "lib/make_pdf/CommandBasedRenderer.rb",
    "lib/make_pdf/Firefox.rb"
  ]
  s.homepage    =
    "https://rubygems.org/gems/make_pdf-jekyll"
  s.license       = "MIT"
end

