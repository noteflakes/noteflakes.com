Executive = import '_lib/executive'

export ->(req) {
  req.respond_sse do
    send_update(req)
    @machine.periodically(1) { send_update(req) }
  end
}

def send_update(req)
  json = JSON.dump(Executive.info)
  req.send_event('datastar-patch-signals' => "signals #{json}")
end
