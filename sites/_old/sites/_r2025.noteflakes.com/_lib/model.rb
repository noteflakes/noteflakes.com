require 'syntropy/connection_pool'
require 'fileutils'

class Syntropy::ConnectionPool
  # ConnectionPool extension (to be extracted into Syntropy)
  def query(sql, *, **, &)
    with_db { it.query(sql, *, **, &) }
  end

  def execute(sql, *, **)
    with_db { it.execute(sql, *, **) }
  end
end

class Model
  def initialize(env)
    @env = env
    @machine = env[:machine]
    @fn = "data/gathering.db"
    @cp = Syntropy::ConnectionPool.new(@machine, @fn, 4)
    prepare_db
  end

  def get_participants(activity_id)
    @cp.query("
      select * from participations
      where activity_id = ?
      order by stamp
    ", activity_id
    )
  end

  def add_participant(activity_id, participant_name)
    @cp.execute("
      insert into participations (
        stamp, activity_id, participant_name
      )
      values (?, ?, ?)
    ", Time.now.to_i, activity_id, participant_name)
  end

  def del_participant(activity_id, participant_name)
    @cp.execute("
      delete from participations
      where activity_id = ? and participant_name = ?
    ", activity_id, participant_name)
  end

  private

  def prepare_db
    @cp.execute <<~SQL
      create table if not exists participations (
        id integer primary key,
        stamp integer,
        activity_id text,
        participant_name text
      );

      create unique index if not exists idx_participations
        on participations (activity_id, participant_name);
    SQL
  end
end

export Model
