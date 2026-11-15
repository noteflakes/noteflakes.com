export self

def connection_pool
  path = @env[:config][:storage][:noteflakes_com][:path]
  @connection_pool ||= ConnectionPool.new(@machine, path, 4)
end

def schema
  Schema.new(module_loader: @module_loader, schema_root: '_schema')
end

def migrate!
  schema.apply(connection_pool)
end
