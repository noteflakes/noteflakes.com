export template_xml { |articles:, **props|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'Noteflakes'
      link 'https://noteflakes.com/'
      description 'A website by Sharon Rosner'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'

      articles.each { |e|
        atts = e[:atts]
        item {
          title atts[:title]
          link "https://noteflakes.com#{atts[:url]}"
          guid "https://noteflakes.com#{atts[:url]}"
          pubDate atts[:date].to_time.httpdate
          description Papercraft.markdown(e[:markdown])
        }
      }
    }
  }
}
