# require_relative '_lib/analytics'

# @env[:analytics] = analytics = Analytics.new(@machine, File.join(__dir__, '_data/analytics.db'), @env)

app = Syntropy.route_by_host(@env,
  'noteflakes.localhost:1234'       => 'noteflakes.com',
  'papercraft-talk.localhost:1234'  => 'papercraft-minitalk.noteflakes.com',
  'tolkora.localhost:1234'          => 'tolkora.net'
)
export app

# @machine.spin do
#   @machine.periodically(10) {
#     @env[:logger]&.info(message: "headers_map.size => #{TP2::HTTP1Connection.headers_map.size}")
#   }
# end

# export analytics.wrap(app)
