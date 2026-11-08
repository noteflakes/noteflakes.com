Executive = import '_lib/executive'

export ->(req, app) {
  if req.path =~ /\.php$/
    #
  else
    begin
      Executive.inc_connections
      app.(req)
    ensure
      Executive.dec_connections
    end
  end
}
