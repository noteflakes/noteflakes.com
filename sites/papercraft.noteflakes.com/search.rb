Pages = import '_pages'

export ->(req) {
  results = Pages.search(req.query[:s])
  req.respond(JSON.dump(results), 'Content-Type' => Qeweney::MimeTypes[:json])
}
