game = import '/gol/_game'
template = import '/gol/_board'

@subscribers = Set.new
def each_update(&block)
  mailbox = Fiber.current.mailbox
  @subscribers << mailbox
  loop do
    html = @machine.shift(mailbox)
    yield(html)
  end
ensure
  @subscribers.delete(mailbox)
end

@machine.spin {
  game.each_update { |board|
    html = template.render(board)
    @subscribers.each { |m| @machine.push(m, html) }
  }
}

export ->(req) {
  req.validate_http_method('get')
  req.auto_compress!
  req.respond_sse {
    last_connected_count = @subscribers.size
    each_update { |html|
      req.send_ds_html_patch(html)

      if @subscribers.size != last_connected_count
        last_connected_count = @subscribers.size
        json = JSON.dump(connected_count: last_connected_count)
        req.send_event('datastar-patch-signals' => "signals #{json}")
      end
    }
  }
}
