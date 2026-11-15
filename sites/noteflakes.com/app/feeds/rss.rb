template = import '/_templates/rss'

export ->(req) {
  articles = MODULE.page_list('/articles').select { !it[:atts][:draft] }.reverse
  req.respond(template.render(articles:), 'Content-Type' => 'text/xml; charset=UTF-8')
}
