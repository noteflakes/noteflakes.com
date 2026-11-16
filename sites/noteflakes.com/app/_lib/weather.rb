require 'uri'

export self

@http_client = Syntropy::HTTP::Client.new(@machine)

@geolocations = {}
@forecasts = {}

# @param name [String] location name
# @return [Array<Float>] geolocation (lat, long)
def geolocate(name)
  cache(@geolocations, name, 86400 * 30) { query_geolocation(name) }
end

# @param name [String] location name
# @return [Array<Hash>] forecast
def forecast(name, **)
  latitude, longitude = geolocate(name)
  cache(@forecasts, name, 1800) { query_forecast(latitude, longitude) }
end

def cache(hash, key, ttl)
  if (entry = hash[key]) && entry[:stamp] >= Time.now - ttl
    return entry[:value]
  end

  yield.tap { hash[key] = { stamp: Time.now, value: it } }
end

def query_geolocation(name)
  url = "https://geocoding-api.open-meteo.com/v1/search?name=#{URI.encode_www_form_component(name)}&count=4&language=en&format=json"
  headers, body = @http_client.get(url, 'Accept' => 'application/json', 'User-Agent' => 'curl/8.18.0')
  raise if headers[':status'] != 200

  json = JSON.parse(body, symbolize_names: true)
  results = json[:results]
  raise "Could not get geolocation for #{name}" if !results

  entry = results[0]
  raise "Could not get geolocation for #{name}" if !entry

  [entry[:latitude], entry[:longitude]]
end

# See:
# https://open-meteo.com/en/docs?hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,apparent_temperature,wind_speed_10m,is_day,wind_direction_10m&daily=weather_code,sunrise,sunset,precipitation_sum,daylight_duration,wind_speed_10m_max,precipitation_probability_max,temperature_2m_max,temperature_2m_min,uv_index_max,wind_direction_10m_dominant&timezone=auto&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day,wind_direction_10m,wind_gusts_10m

FORECAST_PARAMS = {
  daily: %w(
    daylight_duration
    precipitation_probability_max
    precipitation_sum
    sunrise
    sunset
    temperature_2m_max
    temperature_2m_min
    uv_index_max
    weather_code
    wind_direction_10m_dominant
    wind_speed_10m_max
  ),
  hourly: %w(
    apparent_temperature
    is_day
    precipitation_probability
    relative_humidity_2m
    temperature_2m
    weather_code
    wind_direction_10m
    wind_speed_10m
  ),
  current: %w(
    apparent_temperature
    is_day
    precipitation
    relative_humidity_2m
    temperature_2m
    weather_code
    wind_direction_10m
    wind_gusts_10m
    wind_speed_10m
  ),
  timezone: 'auto'
}

def query_forecast(latitude, longitude)
  query = FORECAST_PARAMS.merge(latitude:, longitude:).map { |k, v|
    "#{k}=#{URI.encode_www_form_component(v.is_a?(Array) ? v.join(',') : v)}"
  }
  url = "https://api.open-meteo.com/v1/forecast?#{query.join('&')}"

  headers, body = @http_client.get(url, 'Accept' => 'application/json', 'User-Agent' => 'curl/8.18.0')
  raise if headers[':status'] != 200

  JSON.parse(body, symbolize_names: true)
end

def weather_code_info(wc, is_day)
  info = WEATHER_CODE_INFO[wc]
  return nil if !info

  {
    description: info[:description],
    img_url: info[is_day == 1 ? :img_day : :img_night]
  }
end

WEATHER_CODE_INFO = {
  0  => {
    description: "Sunny",
    img_day: "http://openweathermap.org/img/wn/01d@2x.png",
    img_night: "http://openweathermap.org/img/wn/01n@2x.png"
  },
  1  => {
    description: "Mainly Sunny",
    img_day: "http://openweathermap.org/img/wn/01d@2x.png",
    img_night: "http://openweathermap.org/img/wn/01n@2x.png"
  },
  2  => {
    description: "Partly Cloudy",
    img_day: "http://openweathermap.org/img/wn/02d@2x.png",
    img_night: "http://openweathermap.org/img/wn/02n@2x.png"
  },
  3  => {
    description: "Cloudy",
    img_day: "http://openweathermap.org/img/wn/03d@2x.png",
    img_night: "http://openweathermap.org/img/wn/03n@2x.png"
  },
  45 => {
    description: "Foggy",
    img_day: "http://openweathermap.org/img/wn/50d@2x.png",
    img_night: "http://openweathermap.org/img/wn/50n@2x.png"
  },
  48 => {
    description: "Rime Fog",
    img_day: "http://openweathermap.org/img/wn/50d@2x.png",
    img_night: "http://openweathermap.org/img/wn/50n@2x.png"
  },
  51 => {
    description: "Light Drizzle",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  53 => {
    description: "Drizzle",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  55 => {
    description: "Heavy Drizzle",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  56 => {
    description: "Light Freezing Drizzle",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  57 => {
    description: "Freezing Drizzle",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  61 => {
    description: "Light Rain",
    img_day: "http://openweathermap.org/img/wn/10d@2x.png",
    img_night: "http://openweathermap.org/img/wn/10n@2x.png"
  },
  63 => {
    description: "Rain",
    img_day: "http://openweathermap.org/img/wn/10d@2x.png",
    img_night: "http://openweathermap.org/img/wn/10n@2x.png"
  },
  65 => {
    description: "Heavy Rain",
    img_day: "http://openweathermap.org/img/wn/10d@2x.png",
    img_night: "http://openweathermap.org/img/wn/10n@2x.png"
  },
  66 => {
    description: "Light Freezing Rain",
    img_day: "http://openweathermap.org/img/wn/10d@2x.png",
    img_night: "http://openweathermap.org/img/wn/10n@2x.png"
  },
  67 => {
    description: "Freezing Rain",
    img_day: "http://openweathermap.org/img/wn/10d@2x.png",
    img_night: "http://openweathermap.org/img/wn/10n@2x.png"
  },
  71 => {
    description: "Light Snow",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  73 => {
    description: "Snow",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  75 => {
    description: "Heavy Snow",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  77 => {
    description: "Snow Grains",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  80 => {
    description: "Light Showers",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  81 => {
    description: "Showers",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  82 => {
    description: "Heavy Showers",
    img_day: "http://openweathermap.org/img/wn/09d@2x.png",
    img_night: "http://openweathermap.org/img/wn/09n@2x.png"
  },
  85 => {
    description: "Light Snow Showers",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  86 => {
    description: "Snow Showers",
    img_day: "http://openweathermap.org/img/wn/13d@2x.png",
    img_night: "http://openweathermap.org/img/wn/13n@2x.png"
  },
  95 => {
    description: "Thunderstorm",
    img_day: "http://openweathermap.org/img/wn/11d@2x.png",
    img_night: "http://openweathermap.org/img/wn/11n@2x.png"
  },
  96 => {
    description: "Light Thunderstorms With Hail",
    img_day: "http://openweathermap.org/img/wn/11d@2x.png",
    img_night: "http://openweathermap.org/img/wn/11n@2x.png"
  },
  99 => {
    description: "Thunderstorm With Hail",
    img_day: "http://openweathermap.org/img/wn/11d@2x.png",
    img_night: "http://openweathermap.org/img/wn/11n@2x.png"
  }
}
