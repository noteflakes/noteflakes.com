require 'json'

export ->(req) {
  req.respond_sse {
    send_time_update(req)
    @machine.periodically(1) { send_time_update(req) }
  }
}

@time_template = ->(time) {
  span "Time: #{time.to_s}", id: "time"
}

def send_time_update(req)
  patch = Papercraft.html(@time_template, Time.now)
  req.send_event('datastar-patch-elements' => "elements #{patch}")
end
