source 'https://rubygems.org'

%w{polyphony qeweney tipi impression}.each do |dep|
  dir = "../#{dep}"
  gem(dep, path: dir) if File.directory?(dir)
end

gem 'rb-inotify',   '0.10.1'
gem 'rubyoshka',    '0.6.1'
gem 'rouge',        '3.26.0'
gem 'nokogiri',     '1.12.3'
gem 'open-uri',     '0.1.0'
gem 'escape_utils', '1.2.1'
gem 'httparty',     '0.18.1'