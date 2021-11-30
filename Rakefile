#!/usr/bin/env rake
require "bundler/gem_tasks"

require 'rake'
require 'rspec/core/rake_task'

task :default => :test
task :test => [:spec]

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/*_spec.rb'
end
