require 'spec_helper'
require 'tempfile'

describe 'talos' do

  def match_query_to_files(query, files)
    get query
    expect(last_response).to be_ok
    Tempfile.open('spec') do |file|
      file.write(last_response.body)
      file.flush
      files_in_archive = `tar -tf #{file.path}`.split
      files.each { |f| expect(files.sort).to eq(files_in_archive.sort) }
    end
  end

  it 'should detect scope and return YAML files' do
    { '/?fqdn=testing.int.sto.example.com' =>
        %w(common.yaml),
      '/?role=puppet&pod=sto3&fqdn=sto3-puppet-a1.sto3.example.com' =>
        %w(common.yaml role/puppet.yaml),
      '/?fqdn=sto3-puppet-a1.sto3.example.com' =>
        %w(common.yaml role/puppet.yaml),
      '/?role=puppet&pod=sto3&fqdn=foo.bar' =>
        %w(common.yaml role/puppet.yaml fqdn/foo.bar.yaml),
      '/?fqdn=something.random&role=foobar&pool=z' =>
        %w(common.yaml role/foobar/z.yaml),
      '/?fqdn=sjc1-puppet-a1' =>
        %w(common.yaml role/puppet.yaml site/sjc.yaml),
      '/?fqdn=sjc1-foobar-a1.cloud.example.com' =>
        %w(common.yaml site/sjc.yaml role/foobar/testing.yaml),
    }.each do |query, files|
      match_query_to_files(query, files)
    end
  end

  it 'should resturn the checksum master symlink to' do
    get '/status'
    expect(last_response).to be_ok
    expect(last_response.body).to match('3fa3fd97848a72ae539b75bccd6028cd1d4e92e3')
  end
end
