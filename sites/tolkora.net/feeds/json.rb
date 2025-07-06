export Papercraft.json(mime_type: 'application/json; charset=utf-8') { |**props|
  version         'https://jsonfeed.org/version/1.1'
  title           'טולקורה'
  home_page_url   'https://tolkora.net/'
  feed_url        'https://tolkora.net/feeds/json'
  authors         [{ url: 'https://tolkora.net/', name: 'Sharon Rosner' }]
  icon            'https://tolkora.net/assets/nf-icon-black.png'
  favicon         'https://tolkora.net/assets/nf-icon-black.png'

  article_entries = MODULE.page_list('/articles').reverse

  items {
    article_entries.each do |e|
      item(
        title:          e[:title],
        date_published: e[:date].to_time.xmlschema,
        date_modified:  e[:date].to_time.xmlschema,
        id:             e[:url],
        url:            "https://tolkora.net#{e[:url]}",
        authors:        [{ url: 'https://tolkora.net/', name: 'Sharon Rosner' }],
        content_html:   e[:html_content]
      )
    end
  }
}
