export ->(req) {
  req.respond(req.headers.to_json, 'Content-Type' => Qeweney::MimeTypes[:json])
}
