export self

@updates = @machine.broadcaster
def updates = @updates

def machine_stats
  {
    time:         Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    load_avg:     File.read('/proc/loadavg').split.first,
    connections:  Syntropy::HTTP::ServerConnection.count
  }
end

update_fiber = @machine.spin {
  @machine.periodically(1) {
    stats = machine_stats rescue nil
    @updates.broadcast(stats) if stats
  }
}
on_unload { @machine.terminate(update_fiber) }
