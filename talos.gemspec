Gem::Specification.new do |s|
  s.version       = '0.1.12'
  s.name          = 'talos'
  s.authors       = ['Alexey Lapitsky', 'Johan Haals']
  s.email         = 'alexey@spotify.com'
  s.summary       = %q{Hiera secrets distribution over HTTP}
  s.description   = %q{Distribute compressed hiera yaml files to authenticated puppet clients over HTTP}
  s.homepage      = 'https://github.com/spotify/talos'
  s.license       = 'Apache-2.0'

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_dependency 'rack', '2.2.3'
  s.add_dependency 'sinatra', '~> 2.0.8'
  s.add_dependency 'hiera', '~> 3.6.0'
  s.add_dependency 'archive-tar-minitar', '~> 0.5.2'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sinatra-contrib'
  s.add_development_dependency 'rspec', '>= 2.9'
end
