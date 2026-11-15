export ->(req) {
  req.validate_http_method('get')
  req.respond_sse {
    send_time_update(req)
    @machine.periodically(1) {
      send_time_update(req)
    }
  }
}

def send_time_update(req)
  req.send_event(
    'datastar-patch-signals' => "signals { _states: { '/time': \"#{Time.now.to_s}\" } }"
  )
end
