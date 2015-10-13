lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

class Bsp; end
require 'bsp/version.rb'


gemspec = Gem::Specification.new do |gem|
  gem.name = "bsp"
  gem.version = Bsp::VERSION::STRING
  gem.summary = "Bsp is a simple reader for JPL BSP ephemerides files"
  #gem.description = ""
  #gem.homepage = 'http://sciruby.com'
  gem.authors = ['John Woods']
  gem.email =  ['john.woods@intuitivemachines.com']
  gem.license = 'BSD 3-clause'
  gem.files = `git ls-files -- lib`.split("\n")
  gem.test_files = `git ls-files -- spec`.split("\n")
  gem.require_paths = ["lib"]
  gem.required_ruby_version = '>= 1.9'

  gem.add_dependency 'packable', '~> 1.3', '>= 1.3.6'
  gem.add_development_dependency 'bundler', '~>1.6'
  gem.add_development_dependency 'pry', '~>0.10'
  gem.add_development_dependency 'rake', '~>10.3'
  gem.add_development_dependency 'rdoc'
  gem.add_development_dependency 'rspec', '~>2.14'
end
