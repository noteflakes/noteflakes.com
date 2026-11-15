export self

def render(articles:)
  items = articles.map do |a|
    atts = a[:atts]
    {
      title:          atts[:title],
      date_published: atts[:date].to_time.xmlschema,
      date_modified:  atts[:date].to_time.xmlschema,
      id:             atts[:url],
      url:            "https://noteflakes.com#{atts[:url]}",
      authors:        [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }],
      content_html:   Papercraft.markdown(a[:markdown])
    }
  end
  
  {
    version:        'https://jsonfeed.org/version/1.1',
    title:          'Noteflakes',
    home_page_url:  'https://noteflakes.com/',
    feed_url:       'https://noteflakes.com/feeds/json',
    authors:        [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }],
    icon:           'https://noteflakes.com/assets/nf-icon-black.png',
    favicon:        'https://noteflakes.com/assets/nf-icon-black.png',
    items:
  }
end
