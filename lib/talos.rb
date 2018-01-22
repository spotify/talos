#!/usr/bin/env ruby
#--
# Copyright 2015 Spotify AB
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#++

require 'sinatra/base'
require 'json'
require 'hiera'
require 'stringio'
require 'zlib'
require 'archive/tar/minitar'
require 'pathname'
include Archive::Tar


class Talos < Sinatra::Base
  def self.prepare_config(path)
    set :talos, YAML.load_file(path)
    settings.talos['ssl'] = true if settings.talos['ssl'].nil?
    settings.talos['scopes'].each do |scope_config|
      begin
        scope_config['regexp'] = Regexp.new(scope_config['match'])
      rescue
        fail "Invalid regexp: #{scope_config['match']}"
      end
    end
  end

  configure :development, :test do
    require 'sinatra/reloader'
    register Sinatra::Reloader
    set :hiera, Hiera::Config::load(File.expand_path('spec/fixtures/hiera.yaml'))
    prepare_config('spec/fixtures/talos.yaml')
    set :show_exceptions, false
  end

  configure :production do
    set :hiera, Hiera::Config::load(File.expand_path('/etc/talos/hiera.yaml'))
    prepare_config('/etc/talos/talos.yaml')
    warn("SECURITY WARNING: use of ssl is disabled, client requests cannot be authenticated") if !settings.talos['ssl']
    warn("SECURITY WARNING: unsafe_scopes are enabled, SSL authentication bypass is possible") if settings.talos['unsafe_scopes']
  end

  def absolute_datadir
    datadir = settings.hiera[:yaml][:datadir]
    Pathname.new(datadir).relative? ? File.join(File.dirname(__FILE__), '..', datadir) : datadir
  end

  # Extracts scopes from FQDN using regexp with named captures
  # Falls back to insecure arguments passed by the puppet agent
  # (needed for the hosts not following naming convention)
  def get_scope(fqdn)
    scope = {'fqdn' => fqdn}
    settings.talos['scopes'].each do | scope_config|
      if m = fqdn.match(scope_config['regexp'])
        scope.update(Hash[ m.names.zip( m.captures ) ])
        scope.update(scope_config['facts'])
      end
    end

    unsafe_scope = settings.talos['unsafe_scopes'] ? request.env['rack.request.query_hash'] : {}
    scope.update(unsafe_scope)
    # scope = {"pod"=>"lon3", "site"=>"lon", "role"=>"puppet", "pool"=>"a"}
    scope
  end

  def files_in_scope(scope)
    files = []
    Hiera::Backend.datasources(scope, nil) do |source, yamlfile|
      yamlfile = Hiera::Backend.datafile(:yaml, scope, source, 'yaml') || next
      next unless File.exist?(yamlfile)
      # Strip path from filename
      files << yamlfile.gsub(settings.hiera[:yaml][:datadir] + '/', '')
    end
    files
  end

  def compress_files(files)
    output = StringIO.new
    begin
      sgz = Zlib::GzipWriter.new(output)
      tar = Minitar::Output.new(sgz)
      Dir.chdir(absolute_datadir) { files.each { |f| Minitar.pack_file(f, tar) } }
    ensure
      tar.close
    end
    output
  end

  get '/' do
    fqdn = (settings.development? || !settings.talos['ssl']) ? params[:fqdn] : request.env['HTTP_SSL_CLIENT_S_DN_CN']
    scope = get_scope(fqdn)
    files_to_pack = files_in_scope(scope)
    archive = compress_files(files_to_pack)
    content_type 'application/x-gzip'
    archive.string
  end

  # Get the checksum the data folder symlink to
  # Internal API
  get '/status' do
    begin
      File.readlink(absolute_datadir).split('.').last
    rescue
      halt 'Failed to fetch commit id'
    end
  end

  run! if app_file == $0
end
