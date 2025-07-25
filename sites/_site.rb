require_relative '_lib/analytics'

@env[:analytics] = analytics = Analytics.new(@machine, File.join(__dir__, '_data/analytics.db'), @env)

app = route_by_host(
  '192.168.0.100:1234' => 'r2025.noteflakes.com',
  'localhost:1234' => 'r2025.noteflakes.com',
  'localhost' => 'noteflakes.com',
)

export analytics.wrap(app)
