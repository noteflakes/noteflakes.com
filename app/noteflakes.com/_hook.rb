# frozen_string_literal: true

export ->(req, app) {
  if req.path =~ /\.php$/
    
  else
    app.(req)
  end
}
