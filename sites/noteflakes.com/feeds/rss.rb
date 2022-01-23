require 'papercraft'

export_default Papercraft.xml(mime_type: 'text/xml; charset=utf-8') { |resource:, **props|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'Noteflakes'
      link 'https://noteflakes.com/'
      description 'A website by Sharon Rosner'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'
      
      article_entries = resource.page_list('/articles').reverse

      article_entries.each { |e|
        item {
          title e[:title]
          link "https://noteflakes.com#{e[:url]}"
          guid "https://noteflakes.com#{e[:url]}"
          pubDate e[:date].to_time.httpdate
          description e[:html_content]
        }  
      }
    }
  }
}
