template = import '/_templates/home'

export ->(req) {
  last_article = MODULE.page_list('/articles').select { !it[:atts][:draft] }.last
  req.respond_html(template.render(last_article:))
}
