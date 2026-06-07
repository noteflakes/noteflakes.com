export Syntropy.route_by_host(
  @env,
  'localhost:1234' => 'noteflakes.com',
  'noteflakes.localhost:1234' => 'noteflakes.com',
  'papercraft.localhost:1234' => 'papercraft.noteflakes.com',
  'tolkora.localhost:1234'    => 'tolkora.net',
  'papercraft-talk.localhost:1234'  => 'papercraft-minitalk.noteflakes.com'
)
