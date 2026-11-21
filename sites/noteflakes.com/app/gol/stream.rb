game = import '/gol/_game'
template = import '/gol/_board'

html_updates = @machine.broadcaster
update_fiber = @machine.spin {
  game.board_updates.each { |board|
    next if html_updates.listener_count == 0

    html = template.render(board)
    html_updates.broadcast(html)
  }
}
on_unload { @machine.terminate(update_fiber) }

export ->(req) {
  req.validate_http_method('get')
  req.auto_compress!
  req.respond_sse {
    last_connected_count = html_updates.listener_count
    req.send_ds_signal_patch(connected_count: last_connected_count)
    html_updates.each { |html|
      req.send_ds_html_patch(html)

      connected_count = html_updates.listener_count
      if connected_count != last_connected_count
        last_connected_count = connected_count
        req.send_ds_signal_patch(connected_count: connected_count)
      end
    }
  }
}
