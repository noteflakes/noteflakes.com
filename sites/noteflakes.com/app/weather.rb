layout = import '/_layout/default'
weather = import '/_lib/weather'

template = layout.apply(title: 'Weather') { |current:, **|
  winfo = weather.weather_code_info(current[:weather_code], current[:is_day])

  h1 'Current weather in Martigny-le-Comte'

  div(class: 'weather') {
    if winfo
      h2 {
        span winfo[:description]
        img src: winfo[:img_url]
      }
    end
    p "Temperature: #{current[:temperature_2m]} °C (feels like: #{current[:apparent_temperature]} °C)"
    p "Humidity: #{current[:relative_humidity_2m]} %"
    p "Wind: #{current[:wind_speed_10m]} km/h (#{current[:wind_gusts_10m]} km/h) direction: #{current[:wind_direction_10m]} °"
    
  }
}


export ->(req) {
  forecast = weather.forecast('Martigny-le-Comte')
  pp forecast[:current]
  req.respond_html(template.render(**forecast))
}
