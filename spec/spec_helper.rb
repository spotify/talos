require File.join(File.dirname(__FILE__), '../lib/talos.rb')

require 'sinatra'
require 'rack/test'
Talos.environment = :development
set :run, false
set :raise_errors, true
set :logging, true

def app
  Talos
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
