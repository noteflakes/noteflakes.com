layout = import '/_layout/default'
meteo = import '/_lib/meteo'

template = layout.apply(title: 'Weather') { |stamp:, current:, daily:, **|
  winfo = meteo.weather_code_info(current[:weather_code], current[:is_day])

  h1 "Current weather in Martigny-le-Comte (#{stamp.strftime('%d/%m %H:%M')})"

  div(class: 'weather') {
    if winfo
      h2 {
        img src: winfo[:img_url]
        span winfo[:description]
      }
    end
    p "Temperature: #{current[:temperature_2m]}°C (feels like: #{current[:apparent_temperature]}°C)"
    p "Humidity: #{current[:relative_humidity_2m]}%"
    p "Precipitation: #{current[:precipitation]} mm"
    dir = meteo.wind_direction(current[:wind_direction_10m])
    p "Wind: #{current[:wind_speed_10m]} km/h #{dir} (#{current[:wind_gusts_10m]} km/h)"
  }

  h2 'Forecast'

  div(class: 'weather', style: 'font-size: 0.8em') {
    table {
      thead {
        tr {
          daily[:time].each { |d|
            d = Time.parse(d)
            th d.strftime('%a %d/%m')
          }
        }
      }
      tbody {
        tr {
          daily[:weather_code].each { |wc|
            wi = meteo.weather_code_info(wc, nil)
            td { img src: wi[:img_url] }
          }
        }
        tr {
          daily[:temperature_2m_min].each_with_index { |v, i|
            min = v
            max = daily[:temperature_2m_max][i]
            td "#{min} - #{max}°C"
          }
        }
        tr {
          daily[:precipitation_sum].each_with_index { |v, i|
            sum = v
            prob = daily[:precipitation_probability_max][i]
            td "#{prob}% (#{sum} mm)"
          }
        }
        tr {
          daily[:wind_speed_10m_max].each_with_index { |v, i|
            speed = v
            dir = meteo.wind_direction(daily[:wind_direction_10m_dominant][i])
            td "#{speed} km/h #{dir}"
          }
        }
      }
    }
  }
}


export ->(req) {
  forecast = meteo.forecast('Martigny-le-Comte')
  req.respond_html(template.render(**forecast))
}
