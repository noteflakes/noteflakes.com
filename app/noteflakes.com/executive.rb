template = import '_templates/executive'

export ->(req) {
  req.respond_html(template.render)
}
