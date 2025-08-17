Template = -> {
  div { p 'hi' }
}

export ->(req) {
  req.respond(Template.render, 'Content-Type' => 'text/html')
}
