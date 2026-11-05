require 'json'

export ->(req) {
  req.respond_sse {
    send_time_update(req)
    @machine.periodically(1) { send_time_update(req) }
  }
}

def send_time_update(req)
  json = JSON.dump(time: Time.now.to_s)
  req.send_event('datastar-patch-signals' => "signals #{json}")
end
