layout = import '/_layout/default'

export layout.apply(title: 'Executive') { |**|
  script type: "module", src: "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js"

  last_month = nil

  h1 'Current server state'

  div(data_init: "@get('./executive_stream')") {
    p {
      span 'Time: '
      span data_text: "$time"
    }
    p {
      span 'Load average: '
      span data_text: "$load_avg"
    }
    p {
      span 'Connections: '
      span data_text: "$connections"
    }
  }
}
