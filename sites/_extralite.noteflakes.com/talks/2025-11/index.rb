# frozen_string_literal: true

export ->(req) {
  # req.respond('blah')
  req.redirect('/talks/2025-11/pages/0-01')
}
