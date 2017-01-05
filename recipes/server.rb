#
# Cookbook Name:: openvpn
# Recipe:: server
#
# Copyright 2009-2013, Chef Software, Inc.
# Copyright 2015, Chef Software, Inc. <legal@chef.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe 'openvpn::enable_ip_forwarding'
include_recipe 'openvpn::install_bridge_utils' if node['openvpn']['type'] == 'bridge'
include_recipe 'openvpn::install'

# this recipe currently uses the bash resource, ensure it is installed
p = package 'bash' do
  action :nothing
end
p.run_action(:install)

# in the case the key size is provided as string, no integer support in metadata (CHEF-4075)
node.override['openvpn']['key']['size'] = node['openvpn']['key']['size'].to_i

key_dir  = node['openvpn']['key_dir']
key_size = node['openvpn']['key']['size']
message_digest = node['openvpn']['key']['message_digest']

directory key_dir do
  owner 'root'
  group node['openvpn']['root_group']
  recursive true
  mode  '0700'
end

template [node['openvpn']['fs_prefix'], '/etc/openvpn/server.up.sh'].join do
  source 'server.up.sh.erb'
  owner 'root'
  group node['openvpn']['root_group']
  mode  '0755'
  notifies :restart, 'service[openvpn]'
end

directory [node['openvpn']['fs_prefix'], '/etc/openvpn/server.up.d'].join do
  owner 'root'
  group node['openvpn']['root_group']
  mode  '0755'
end

require 'openssl'

file node['openvpn']['config']['dh'] do
  content lazy { OpenSSL::PKey::DH.new(key_size).to_s }
  owner   'root'
  group   node['openvpn']['root_group']
  mode    '0600'
  not_if  { ::File.exist?(node['openvpn']['config']['dh']) }
end

include_recipe 'openvpn::setup_ca' if node['openvpn']['configure_default_certs']

# the FreeBSD service expects openvpn.conf
conf_name = if node['platform'] == 'freebsd'
              'openvpn'
            else
              'server'
            end

openvpn_conf conf_name do
  notifies :restart, 'service[openvpn]'
  only_if { node['openvpn']['configure_default_server'] }
  action :create
end

include_recipe 'openvpn::service'
