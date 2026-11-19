game = import '/gol/_game'

IDX_RANGE = 0...(game.size ** 2)

export ->(req) {
  req.validate_http_method('post')
  idx = req.validate_param('idx', Integer, IDX_RANGE)
  game.fill_cross(idx, req.session['game_color'])
  req.respond(nil)
}
