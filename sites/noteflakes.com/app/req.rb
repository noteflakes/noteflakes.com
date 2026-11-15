export ->(req) {
  response = {
    request_headers: req.headers,
    query: req.query
  }
  req.respond(response.to_json, 'Content-Type' => Qeweney::MimeTypes[:json])
}
