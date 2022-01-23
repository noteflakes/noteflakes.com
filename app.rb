# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'
require 'modulation'

sites = {
  'noteflakes.com' => (import './sites/noteflakes.com/site.rb').to_proc
}

sites[nil] = sites['noteflakes.com']

Tipi.run do |req|
  host = req.host
  app = sites[host] || sites[nil]
  if app
    app.call(req)
  else
    req.respond(nil, ':status' => Qeweney::Status::NOT_FOUND)
  end
end

# Tipi.run_sites(
#   'noteflakes.com' => (import './sites/noteflakes.com/site.rb'),
#   'h.noteflakes.com' => (import './sites/h.noteflakes.com/site.rb'),
#   'httipi.net' => (import './sites/httipi.net/site.rb')
# )


# # This should go into Impression
# def site_router(sites, &block)
#   domain_routers = sites.each_with_object({}) do |s, h|
#     domain, handler = block.(s)
#     h[domain] = handler
#   end
#   proc do |req|
#     host = req.host
#     handler = domain_routers[host]
#     req.route_found { handler.call(req) } if handler
#   end
# end

# def app
#   route_by_host = site_router(Dir['sites/*']) do |path|
#     domain = File.basename(path)
#     m = import(File.join(path, 'site.rb'))
#     [domain, m]
#   end
    
#   proc do |req|
#     p req.headers
#     req.route do
#       route_by_host.(req)

#       req.reject(nil, Qeweney::Status::SERVICE_UNAVAILABLE)
#     end
#   end
# end
