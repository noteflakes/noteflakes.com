export template { |p, c, n|
  cur c
  nav {
    if p
      a('▲', href: '0-01', class: 'first')
    else
      span(class: 'first')
    end

    if p
      a('◀', href: p, class: 'prev')
    else
      span(class: 'prev')
    end
    if n
      a('▶', href: n, class: 'next')
    else
      span(class: 'next')
    end
  }
}
