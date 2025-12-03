# frozen_string_literal: true

require_relative "lib/apple_school_manager/version"

Gem::Specification.new do |spec|
  spec.name = "apple_school_manager"
  spec.version = AppleSchoolManager::VERSION
  spec.authors = ["University of Michigan"]
  spec.email = [""]

  spec.summary = "Ruby client for Apple School Manager API"
  spec.description = "A Ruby gem for interacting with the Apple School Manager API to manage device inventory and MDM server assignments"
  spec.homepage = "https://github.com/umich-mac/izzy-school-manager"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "bug_tracker_uri" => "https://github.com/umich-mac/izzy-school-manager/issues",
    "github_repo" => "ssh://github.com/umich-mac/izzy-school-manager"
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{lib,spec,bin}/**/*") + %w[README.md LICENSE.txt]
  spec.bindir = "bin"
  spec.executables = ["asm"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "csv", "~> 3.3"
  spec.add_dependency "http", "~> 5.3"
  spec.add_dependency "jwt", "~> 3.1"

  # Development dependencies
  spec.add_development_dependency "faker", "~> 3.5"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "standard", "~> 1.52"
end
