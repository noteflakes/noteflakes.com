Layout = import '_layout/docs'
Pages = import '_pages'

export ->(req) {
  href = req.path
  entry = Pages[href]
  if entry
    html = Layout.render(page_title: entry[:title], pages: Pages, href:, entry:)
    req.respond(html, 'Content-Type' => Qeweney::MimeTypes[:html])
  else
    raise Syntropy::Error.not_found
    # Pages[:entry_map].inspect
    # req.respond(path)
  end
}
