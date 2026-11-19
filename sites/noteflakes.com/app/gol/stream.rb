game = import '/gol/_game'
template = import '/gol/_board'

export ->(req) {
  req.validate_http_method('get')
  req.respond_sse {
    game.each_update { |board|
      req.send_ds_html_patch(template.render(board))
    }
  }
}
