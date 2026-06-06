message_eng = 'Stop the war, stop the occupation!'
message_heb = 'די למלחמה, די לכיבוש!'

export template {
  div(class: 'center') {
    banner(class: 'palestine') {
      a('🇵🇸', class: 'flag')
      span(class: 'messages') {
        p(message_eng)
        p(message_heb, class: 'rtl')
      }
    }
  }
}
