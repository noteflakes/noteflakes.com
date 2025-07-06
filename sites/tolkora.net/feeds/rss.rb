export Papercraft.xml(mime_type: 'text/xml; charset=utf-8') { |**props|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'טולקורה'
      link 'https://tolkora.net/'
      description 'טול קורה מבין עינייך'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://tolkora.net/feeds/rss" rel="self" type="application/rss+xml" />'

      article_entries = MODULE.page_list('/articles').reverse

      article_entries.each { |e|
        atts = e[:atts]
        item {
          title atts[:title]
          link "https://tolkora.net#{atts[:url]}"
          guid "https://tolkora.net#{atts[:url]}"
          pubDate atts[:date].to_time.httpdate
          description Papercraft.markdown(e[:markdown])
        }
      }
    }
  }
}
