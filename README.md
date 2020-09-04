Talos
=====

[![Gem Version](https://badge.fury.io/rb/talos.svg)](http://badge.fury.io/rb/talos)
[![Build Status](https://travis-ci.org/spotify/talos.png?branch=master)](https://travis-ci.org/spotify/talos)

Talos is a rack application which serves Hiera yaml files over HTTP.
It authorizes clients based on the SSL certificates issued by the Puppet CA and returns only the files in the
[Hiera scope](https://github.com/puppetlabs/docs-archive/blob/master/hiera/3.3/command_line.markdown#json-and-yaml-scopes).

Talos is used to store and distribute secrets via Hiera to the masterless puppet clients.

How it works
------------
Talos listens for incoming HTTP requests and returns compressed hiera
tree based on the client's SSL certificate.

To determine the list of files to send, Talos matches the certificate
common name against a list of regular expressions.

Fetching the tree
-----------------

It's possible to run a cron task or create a wrapper around the puppet
agent. Here's an example of the client-side code which uses local puppet SSL key
to authenticate:

```ruby
require 'puppet'
Puppet[:confdir] = '/etc/puppetlabs/puppet/'
`/usr/bin/curl -s --fail -X GET -k https://talos.internal}/ \
  --cert #{Puppet[:hostcert]} --key #{Puppet[:hostprivkey]} \
  --data-urlencode pool=#{Facter.value(:pool)} > /etc/talos/tree.tar.gz`
`/bin/tar xzf /etc/talos/tree.tar.gz -C /etc/talos/hiera_secrets`
```

In this example the client also passes `pool` variable which will
be included in the Hiera scope if `unsafe_scopes` option is enabled.

The received copy of the tree could be included in the local hiera config
and used in the normal puppet runs.

Configuration
-------------
Talos configuration is stored in `/etc/talos/talos.yaml`:

```yaml
scopes:
  # lon-puppet-a1: site = lon, role = puppet, pool = a
  - match: '(?<site>[[:alpha:]]+)-(?<role>[a-z0-9]+)-(?<pool>[[:alpha:]]+)'
    facts:
      environment: production
  - match: 'cloud\.example\.com'
    facts:
      environment: testing

unsafe_scopes: true
ssl: true
```

When receiving a request, Talos iterates over `scopes` list and matches
the client certificate against the `match` blocks. If the match is
successful, Talos does 2 things:

1. Adds all the named captures from the regexp to the Hiera scope
2. Adds all the `facts` to the Hiera scope

Talos will iterate over all the regexps updating the
Hiera scope, meaning that the later matches will override the existing
scope on collision.

If `unsafe_scopes` option is enabled, Talos will also add all the parameters
passed by the client to the Hiera scope.

The `ssl` option defaults to enabled. When disabled, the `fqdn` query parameter
is used to determine scopes rather than the client certificate.

Hiera
-----
You need to provide `/etc/talos/hiera.yaml` file to configure Hiera
backend on the Talos server:

```yaml
---
:backends:
  - yaml
:hierarchy:
  - 'hiera-secrets/fqdn/%{fqdn}'
  - 'hiera-secrets/role/%{role}/%{pod}/%{pool}'
  - 'hiera-secrets/role/%{role}/%{pod}'
  - 'hiera-secrets/role/%{role}'
  - 'hiera-secrets/pod/%{pod}'
  - 'hiera-secrets/common'
:yaml:
  :datadir: '/etc/puppet'
:merge_behavior: :deeper
```

Talos will use the `datadir` option to search for YAML files and it
will return only the files that match the Hiera scope of the clients.


Installing
----------

You can use [spotify/talos](https://github.com/spotify/puppet-talos)
puppet module to install Talos.

### Manual installation

First, install talos using rubygems:

    $ gem install talos

Create a separate user and Document Root for the Rack application:

    $ useradd talos --system --create-home --home-dir /var/lib/talos
    $ mkdir -p /var/lib/talos/public /var/lib/talos/tmp /etc/talos
    $ chown -R talos:talos /var/lib/talos/ /etc/talos

Then copy [config.ru](config.ru) to `/var/lib/talos/` directory.

You also need to copy and adjust [hiera.yaml](spec/fixtures/hiera.yaml) and
[talos.yaml](spec/fixtures/talos.yaml) configs in `/etc/talos` directory.

### Hiera repository

You need to have a copy of the hiera-secrets repository available on the
talos server. Make sure it's located at the `datadir` specified in
`/etc/talos/hiera.yaml`

### Apache

You can run Talos using Passenger or any other application server. Make
sure you use Puppet SSL keys to validate the client certificates and to
forward `SSL_CLIENT_S_DN_CN` header:

```apacheconf
<VirtualHost *:443>
  DocumentRoot "/var/lib/talos/public"

  <Directory "/var/lib/talos/public">
    Require all granted
  </Directory>

  SSLEngine on
  SSLCertificateFile "/etc/puppetlabs/puppet/ssl/certs/talos.internal.pem"
  SSLCertificateKeyFile "/etc/puppetlabs/puppet/ssl/private_keys/talos.internal.pem"
  SSLCertificateChainFile "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
  SSLCACertificatePath "/etc/ssl/certs"
  SSLCACertificateFile "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
  SSLCARevocationFile "/etc/puppetlabs/puppet/ssl/crl.pem"
  SSLVerifyClient require
  SSLOptions +StdEnvVars +FakeBasicAuth
  RequestHeader set SSL_CLIENT_S_DN_CN "%{SSL_CLIENT_S_DN_CN}s"
</VirtualHost>
```

Contributing
------------
1. Fork the project on github
2. Create your feature branch
3. Open a Pull Request

This project adheres to the [Open Code of Conduct][code-of-conduct]. By
participating, you are expected to honor this code.

[code-of-conduct]:
https://github.com/spotify/code-of-conduct/blob/master/code-of-conduct.md

License
-------
```text
Copyright 2013-2016 Spotify AB

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
