require_relative '_lib/analytics'

@env[:analytics] = analytics = Analytics.new(@machine, File.join(__dir__, '_data/analytics.db'), @env)

app = route_by_host(
  'localhost:1234' => 'noteflakes.com',
  'localhost' => 'noteflakes.com',
)

export analytics.wrap(app)
