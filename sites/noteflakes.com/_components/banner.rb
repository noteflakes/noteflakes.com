require 'papercraft'

message_eng = 'Stop the war, stop the occupation, stop the starvation!'
message_heb = 'הפסיקו את המלחמה, הפסיקו את הכיבוש, הפסיקו את ההרעבה!'

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
