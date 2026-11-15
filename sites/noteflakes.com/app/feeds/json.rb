template = import '/_templates/json'

export ->(req) {
  articles = Syntropy.page_list(@env, '/articles')
  articles = articles.select { !it[:atts][:draft] }.reverse
  req.respond_json(template.render(articles:))
}
