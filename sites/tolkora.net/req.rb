require 'json'

export_default Impression.resource { |req|
  req.respond(req.headers.to_json, 'Content-Type' => Qeweney::MimeTypes[:json])
}
