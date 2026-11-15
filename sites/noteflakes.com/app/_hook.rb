Executive = import '_lib/executive'

export ->(req, app) {
  if req.path =~ /\.php$/
    #
  else
    app.(req)
  end
}
