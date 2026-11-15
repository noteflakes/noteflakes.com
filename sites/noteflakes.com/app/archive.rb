# frozen_string_literal: true

template = import '/_templates/archive'

export ->(req) {
  articles = MODULE.page_list('/articles').select { !it[:atts][:draft] }.reverse
  req.respond_html(template.render(articles:))
}
