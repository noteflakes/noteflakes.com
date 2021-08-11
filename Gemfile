source 'https://rubygems.org'

%w{polyphony qeweney tipi impression}.each do |dep|
  dir = "../#{dep}"
  gem(dep, path: dir) if File.directory?(dir)
end
