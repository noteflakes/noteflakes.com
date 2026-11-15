export self

@info = {
  connections: 0,
  load_avg: 0,
  time: nil
}

@machine.spin {
  @machine.periodically(1) {
    @info[:time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    @info[:load_avg] = File.read('/proc/loadavg').split.first
    @info[:connections] = Syntropy::HTTP::ServerConnection.count
  }
}

def info
  @info
end
