require 'json'

@connection_count = 0

export ->(req) {
  @connection_count += 1
  req.respond_sse do
    send_time_update(req)
    @machine.periodically(1) { send_time_update(req) }
  ensure
    @connection_count -= 1
  end
}

def send_time_update(req)
  json = JSON.dump(
    time: Time.now.to_s,
    connections: @connection_count,
    load_avg: File.read('/proc/loadavg').split.first
  )
  req.send_event('datastar-patch-signals' => "signals #{json}")
end
