default = import '_layout/default'

export default.apply { |title:, date:, **props|
  article(class: 'rtl') { |**props|
    h1 title
    h3 date.strftime('%d·%m·%Y'), class: 'date'
    render_yield(**props)
  }
}
