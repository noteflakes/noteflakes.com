# frozen_string_literal: true

require 'impression'
require 'rubyoshka'
require 'json'
require 'time'

module NoteflakesSite
  class << self
    SITE_DIR = File.expand_path('../sites/noteflakes.com', __dir__)
    PAGES_DIR = File.join(SITE_DIR, 'pages')
    ASSETS_DIR = File.join(SITE_DIR, '_assets')
    
    DEV = ENV['dev'] == '1'
    
    PAGES = Impression::Pages.new(PAGES_DIR, auto_reload: true)
    
    def route(req)
      req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
      req.on('feeds/rss') { req.respond(render_rss_feed, 'Content-Type' => 'text/xml; charset=utf-8') }
      req.on('feeds/json') { req.respond(render_json_feed, 'Content-Type' => 'application/json; charset=utf-8') }
      req.default { PAGES.serve(req) }
    end

    RSSItem = ->(page) {
      H(mode: :xml) {
      }
    }
    
    def render_rss_feed
      H(mode: :xml) {
        rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
          channel {
            title 'Noteflakes'
            link 'https://noteflakes.com/'
            description 'A website by Sharon Rosner'
            language 'en-us'
            pubDate Time.now.httpdate
            emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'
            context[:articles].each { |a|
              item {
                title a.title
                link "https://noteflakes.com#{a.permalink}"
                guid "https://noteflakes.com#{a.permalink}"
                pubDate a.attributes['date'].to_time.httpdate
                description (a.render rescue '?')
              }  
            }
          }
        }
      }.render(articles: all_articles_in_order)

      # H {
      #   emit '<?xml version="1.0" encoding="utf-8"?>'
      #   feed {
      #     title 'Noteflakes'
      #     subtitle 'By Sharon Rosner'
      #     link rel: 'alternate', type: 'text/html', href: 'https://noteflakes.com/'
      #     link rel: 'self', type: 'application/atom+xml', href: 'https://noteflakes.com/feeds/main'
      #     id 'https://noteflakes.com/feeds/main'
      #     updated Time.now.xmlschema
      #     rights 'Copyright © 2021 Sharon Rosner'

      #     context[:articles].each do |a|
      #       content = a.render rescue nil
      #       next unless content

      #       entry {
      #         title a.title
      #         link rel: 'alternate', type: 'text/html', href: "https://noteflakes.com#{a.permalink}"
      #         id a.permalink
      #         published a.attributes['date'].to_time.xmlschema
      #         updated a.attributes['date'].to_time.xmlschema
      #         author {
      #           name 'Sharon Rosner'
      #           uri 'https://noteflakes.com/'
      #         }
      #         content content, type: 'html'
      #       }
      #     end
      #   }
      # }.render(articles: all_articles_in_order)
    end

    def render_json_feed
      {
        version:        'https://jsonfeed.org/version/1.1',
        title:          'Noteflakes',
        home_page_url:  'https://noteflakes.com/',
        feed_url:       'https://noteflakes.com/feeds/json',
        authors: [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }],
        icon:     'https://noteflakes.com/assets/nf-icon-black.png',
        favicon:  'https://noteflakes.com/assets/nf-icon-black.png',
        
        items:    all_articles_in_order.map do |a|
          {
            title:          a.title,
            date_published: a.attributes['date'].to_time.xmlschema,
            date_modified:  a.attributes['date'].to_time.xmlschema,
            id:             a.permalink,
            url:            "https://noteflakes.com#{a.permalink}",
            # external_url:   'https://www.nytimes.com/...',
            authors:        [{ url: 'https://noteflakes.com/', name: 'Sharon Rosner' }],
            content_html:   (a.render rescue '?')
          }
        end
      }.to_json
    end

    def all_articles_in_order
      PAGES
      .select(/^\/articles/)
      .sort_by { |page| page.attributes['date'] }
      .reverse
    end
  end
end

