# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'
require 'modulation'

# This should go into Impression
def site_router(sites, &block)
  domain_routers = sites.each_with_object({}) do |s, h|
    domain, handler = block.(s)
    h[domain] = handler
  end
  proc do |req|
    host = req.host
    handler = domain_routers[host]
    req.route_found { handler.call(req) } if handler
  end
end

route_by_host = site_router(Dir['sites/*']) do |path|
  domain = File.basename(path)
  m = import(File.join(path, 'site.rb'))
  [domain, m]
end

app = proc do |req|
  p req.headers
  req.route do
    route_by_host.(req)

    req.reject(nil, Qeweney::Status::SERVICE_UNAVAILABLE)
  end
end

Tipi.full_service(&app)
