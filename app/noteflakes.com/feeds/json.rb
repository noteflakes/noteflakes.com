export Papercraft.json(mime_type: 'application/json; charset=utf-8') { |resource:, **props|
  version         'https://jsonfeed.org/version/1.1'
  title           'Noteflakes'
  home_page_url   'https://noteflakes.com/'
  feed_url        'https://noteflakes.com/feeds/json'
  authors         [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }]
  icon            'https://noteflakes.com/assets/nf-icon-black.png'
  favicon         'https://noteflakes.com/assets/nf-icon-black.png'

  article_entries = resource.page_list('/articles').select { !it[:atts][:draft] }.reverse

  items {
    article_entries.each do |e|
      item(
        title:          e[:title],
        date_published: e[:date].to_time.xmlschema,
        date_modified:  e[:date].to_time.xmlschema,
        id:             e[:url],
        url:            "https://noteflakes.com#{e[:url]}",
        # external_url:   'https://www.nytimes.com/...',
        authors:        [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }],
        content_html:   e[:html_content]
      )
    end
  }
}
