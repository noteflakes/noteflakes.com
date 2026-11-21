Executive = import '_lib/executive'

export ->(req) {
  req.respond_sse {
    Executive.updates.each { |stats| req.send_ds_signal_patch(stats) }
  }
}
