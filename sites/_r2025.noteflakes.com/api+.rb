Model = import '/_lib/model'
BASE_PATH = '/api'

class Qeweney::Request
  def form_data
    body = read
    Qeweney::Request.parse_form_data(body, headers)
  end

  def respond_json(data, status = Qeweney::Status::OK)
    respond(
      data.to_json,
      ':status'       => status,
      'Content-Type'  => 'application/json'
    )
  end
end

class API
  def initialize(env)
    @env = env
  end

  def call(req)
    activity_id = path_to_activity_id(req.path)
    result = send(req.method.to_sym, activity_id, req)
    req.respond_json(result)
  rescue => e
    error_response(req, e)
  end

  private

  def get(activity_id, req)
    p get: activity_id
    Model
      .get_participants(activity_id)
      .map { it[:participant_name] }
  end

  def post(activity_id, req)
    form_data = req.form_data
    puts '!' * 40
    p post: form_data
    p form_data: form_data
    raise ValidationError, "Bad form data" if !form_data

    participant_name = form_data['participant_name']

    m = participant_name.match(/^\-(.+)$/)
    if m
      Model.del_participant(activity_id, m[1])
    else
      Model.add_participant(activity_id, participant_name)
    end
    :OK
  rescue Extralite::Error
    :OK
  end

  def path_to_activity_id(path)
    m = path.match(/^#{BASE_PATH}\/(.+)$/)
    p path_to_activity_id: path, m: m
    raise ValidationError, "Invalid activity id" if !m

    m[1]
  end

  def error_response(req, err)
    puts '*' * 40
    puts "#{err.class} - #{err.message}"
    p err.backtrace

    http_status = err.respond_to?(:http_status) ?
      err.http_status : Qeweney::Status::INTERNAL_SERVER_ERROR
    error_name = err.class.name.split('::').last

    req.respond_json({ status: error_name, message: err.message }, http_status)
  end
end

export API
