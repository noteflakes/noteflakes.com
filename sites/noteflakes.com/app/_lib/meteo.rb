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
  cache(@forecasts, name, 900) { query_forecast(latitude, longitude) }
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

  json = JSON.parse(body, symbolize_names: true)

  {
    stamp: Time.parse("#{json[:current][:time]} #{json[:timezone_abbreviation]}"),
    current: json[:current],
    daily: json[:daily]
  }
end

def weather_code_info(wc, is_day)
  info = WEATHER_CODE_INFO[wc]
  return nil if !info

  img_key = case is_day
  when 1
    :img_day
  when nil
    :img
  else
    :img_night
  end
  
  {
    description: info[:description],
    img_url: info[img_key]
  }
end

WEATHER_CODE_INFO = {
  0  => {
    description: "Sunny",
    img:        "https://open-meteo.com/images/weather-icons/wi-sunny.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sunny.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-clear.svg"
  },
  1  => {
    description: "Mainly Sunny",
    img:        "https://open-meteo.com/images/weather-icons/wi-sunny.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sunny.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-clear.svg"
  },
  2  => {
    description: "Partly Cloudy",
    img:        "https://open-meteo.com/images/weather-icons/wi-cloudy.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-cloudy.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-cloudy.svg"
  },
  3  => {
    description: "Cloudy",
    img:        "https://open-meteo.com/images/weather-icons/wi-cloudy.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-cloudy.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-cloudy.svg"
  },
  45 => {
    description: "Foggy",
    img:        "https://open-meteo.com/images/weather-icons/wi-fog.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-fog.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-fog.svg",
  },
  48 => {
    description: "Rime Fog",
    img:        "https://open-meteo.com/images/weather-icons/wi-fog.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-fog.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-fog.svg",
  },
  51 => {
    description: "Light Drizzle",
    img:        "https://open-meteo.com/images/weather-icons/wi-sprinkle.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sprinkle.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-sprinkle.svg",
  },
  53 => {
    description: "Drizzle",
    img:        "https://open-meteo.com/images/weather-icons/wi-sprinkle.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sprinkle.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-sprinkle.svg",
  },
  55 => {
    description: "Heavy Drizzle",
    img:        "https://open-meteo.com/images/weather-icons/wi-sprinkle.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sprinkle.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-sprinkle.svg",
  },
  56 => {
    description: "Light Freezing Drizzle",
    img:        "https://open-meteo.com/images/weather-icons/wi-sprinkle.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sprinkle.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-sprinkle.svg",
  },
  57 => {
    description: "Freezing Drizzle",
    img:        "https://open-meteo.com/images/weather-icons/wi-sprinkle.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-sprinkle.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-sprinkle.svg",
  },
  61 => {
    description: "Light Rain",
    img:        "https://open-meteo.com/images/weather-icons/wi-rain.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-rain.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-rain.svg",
  },
  63 => {
    description: "Rain",
    img:        "https://open-meteo.com/images/weather-icons/wi-rain.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-rain.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-rain.svg",
  },
  65 => {
    description: "Heavy Rain",
    img:        "https://open-meteo.com/images/weather-icons/wi-rain.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-rain.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-rain.svg",
  },
  66 => {
    description: "Light Freezing Rain",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  67 => {
    description: "Freezing Rain",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  71 => {
    description: "Light Snow",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  73 => {
    description: "Snow",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  75 => {
    description: "Heavy Snow",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  77 => {
    description: "Snow Grains",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  80 => {
    description: "Light Showers",
    img:        "https://open-meteo.com/images/weather-icons/wi-showers.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-showers.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-showers.svg",
  },
  81 => {
    description: "Showers",
    img:        "https://open-meteo.com/images/weather-icons/wi-showers.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-showers.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-showers.svg",
  },
  82 => {
    description: "Heavy Showers",
    img:        "https://open-meteo.com/images/weather-icons/wi-showers.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-showers.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-showers.svg",
  },
  85 => {
    description: "Light Snow Showers",
    img:        "https://open-meteo.com/images/weather-icons/wi-snow.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  86 => {
    description: "Snow Showers",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-snow.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-snow.svg",
  },
  95 => {
    description: "Thunderstorm",
    img:        "https://open-meteo.com/images/weather-icons/wi-thunderstorm.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-thunderstorm.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-thunderstorm.svg",
  },
  96 => {
    description: "Light Thunderstorms With Hail",
    img:        "https://open-meteo.com/images/weather-icons/wi-hail.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-hail.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-hail.svg",
  },
  99 => {
    description: "Thunderstorm With Hail",
    img:        "https://open-meteo.com/images/weather-icons/wi-hail.svg",
    img_day:    "https://open-meteo.com/images/weather-icons/wi-day-hail.svg",
    img_night:  "https://open-meteo.com/images/weather-icons/wi-night-hail.svg",
  }
}

def wind_direction(angle)
  case angle
  when 0...23, 347..360
    'N'
  when 23...77
    'NE'
  when 78...113
    'W'
  when 113...167
    'SE'
  when 167...203
    'S'
  when 203...257
    'SW'
  when 257...293
    'W'
  when 293...347
    'NW'
  end
end
