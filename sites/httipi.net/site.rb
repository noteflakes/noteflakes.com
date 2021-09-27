# frozen_string_literal: true

export :call

def call(req)
  req.respond('<h1>Tipi!!!!</h1>', 'Content-Type' => 'text/html')
end
