Template = -> {
  div { p 'hi' }
}

export ->(req) {
  req.respond(Papercraft.html(Template, 'Content-Type' => 'text/html')
}
