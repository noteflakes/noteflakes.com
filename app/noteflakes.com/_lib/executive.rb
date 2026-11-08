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
  }
}

def inc_connections
  @info[:connections] += 1
end

def dec_connections
  @info[:connections] -= 1
end

def info
  @info
end
