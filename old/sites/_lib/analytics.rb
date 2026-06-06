# frozen_string_literal: true

class Analytics
  def initialize(machine, fn, opts)
    @machine = machine
    @fn = fn
    @opts = opts
    setup_db
  end

  def process(req)
    @connection_pool.with_db { add_hit(it, req) }
  end

  def wrap(app)
    ->(req) {
      app.(req)
      process(req)
    }
  end

  private

  def setup_db
    @connection_pool = Syntropy::ConnectionPool.new(@machine, @fn, 4)
    @connection_pool.with_db { setup_schema(it) }
  end

  def setup_schema(db)
    db.transaction do
      db.execute "
        create table if not exists hits (
          ts integer,
          client_ip text,
          host text,
          path text,
          user_agent text,
          http_status integer
        );

        create index if not exists idx_hits_ts
          on hits (ts);
        create index if not exists idx_hits_host_ts
          on hits (host, ts);
        create index if not exists idx_hits_client_ip
          on hits (client_ip);
      "
    end
  end

  def add_hit(db, req)
    headers = req.headers
    db.execute(
      'insert into hits values (?, ?, ?, ?, ?, ?)',
      Time.now.to_i,
      req.forwarded_for,
      req.host,
      headers[':path'],
      headers['user-agent'],
      req.adapter.response_headers[':status'] || 200
    )
  end
end
