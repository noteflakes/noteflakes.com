default = import '_layout/default'
banner = import './_components/banner'

export default.apply { |title:, date:, **props|
  render(banner)
  article {
    h1 title
    h3 date.strftime('%d·%m·%Y'), class: 'date'
    render_yield(**props)
  }
}
