Gem::Specification.new do |s|
  s.name          = 'where-or'
  s.version       = '0.1.5'
  s.authors       = ['Benjamin Fleischer', 'Eric Guo']
  s.email         = 'eric.guo@sandisk.com'
  s.description   = 'Where or function backport from Rails 5 for Rails 4.2'
  s.summary       = s.description
  s.homepage      = 'https://github.com/Eric-Guo/where-or'
  s.license       = 'MIT'

  s.files = Dir['{lib}/**/*']
  s.extra_rdoc_files = ['LICENSE.txt', 'README.md']

  s.cert_chain  = ['certs/Eric-Guo.pem']
  s.signing_key = File.expand_path('~/.ssh/gem-private_key.pem') if $PROGRAM_NAME.end_with?('gem')

  s.add_development_dependency 'rails', '>= 4.2.3', '< 5'
end
