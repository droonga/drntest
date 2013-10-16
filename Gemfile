source "https://rubygems.org"

base_dir = File.dirname(__FILE__)
local_droonga_client_ruby_dir = File.join(base_dir, "..", "droonga-client-ruby")
local_droonga_client_ruby_dir = File.expand_path(local_droonga_client_ruby_dir)
if File.exist?(local_droonga_client_ruby_dir)
  gem "droonga-client", path: local_droonga_client_ruby_dir
else
  gem "droonga-client", github: "droonga/droonga-client-ruby"
end
