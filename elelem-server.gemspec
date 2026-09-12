# frozen_string_literal: true

require_relative "lib/elelem/server/version"

Gem::Specification.new do |spec|
  spec.name = "elelem-server"
  spec.version = Elelem::Server::VERSION
  spec.authors = ["mo khan"]
  spec.email = ["mo@mokhan.ca"]

  spec.summary = "A web UI server plugin for elelem."
  spec.description = "A web UI server plugin for elelem."
  spec.homepage = "https://src.mokhan.ca/elelem/server"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = ["elelem-server"]
  spec.require_paths = ["lib"]

  spec.add_dependency "elelem", "~> 0.12"
  spec.add_dependency "json", "~> 3.0"
  spec.add_dependency "webrick", "~> 1.9"
end
