Gem::Specification.new do |s|
  s.name                  = 'make_pdf-jekyll'
  s.version               = '0.1.0'
  s.summary               = 'Create PDF along side of HTML files for site.'
  s.description           = 'Allows that some documents, or pages to have a pdf version pre generated.'
  s.authors               = ['Victor Bogado da Silva Lins']
  s.email                 = 'victor@bogado.net  '
  s.required_ruby_version = '>= 4.0.0'
  s.files = [
    'lib/make_pdf/chrome.rb',
    'lib/make_pdf/firefox.rb',
    'lib/make_pdf/command_based.rb',
    'lib/make_pdf/jekyll.rb',
    'lib/make_pdf.rb'
  ]
  s.homepage              = 'https://github.com/bogado/make_pdf-jekyll'
  s.license               = 'MIT'
end
