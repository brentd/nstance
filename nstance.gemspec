# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nstance/version'

Gem::Specification.new do |spec|
  spec.name          = "nstance"
  spec.version       = Nstance::VERSION
  spec.authors       = ["Brent Dillingham"]
  spec.email         = ["brentdillingham@gmail.com"]

  spec.summary       = %q{A library for running shell commands in sandboxed environments}

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "docker-api", "~> 1.33.2"
  spec.add_dependency "excon", ">= 0.55.0"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5.0"
end
