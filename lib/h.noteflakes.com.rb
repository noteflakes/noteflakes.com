# frozen_string_literal: true

require 'uri'
require 'nokogiri'
require 'time'
require 'rubyoshka'
require 'impression'
require 'escape_utils'
require 'httparty'

module HaaretzFeedSite
  class << self
    SITE_DIR = File.expand_path('../sites/h.noteflakes.com', __dir__)
    # PAGES_DIR = File.join(SITE_DIR, 'pages')
    ASSETS_DIR = File.join(SITE_DIR, '_assets')

    # PAGES = Impression::Pages.new(PAGES_DIR, auto_reload: true)
    
    def route(req)
      req.on_root { req.respond(render_index, 'Content-Type' => 'text/html') }
      req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
    end

    def render_index
      update if should_update?

      @rendered_index
    end

    def should_update?
      now = Time.now
      if !@last_stamp || now - @last_stamp >= 3600
        @last_stamp = now
        true
      else
        false
      end
    end

    def update
      @rendered_index = index_template.render(articles: article_list)
    end

    def index_template
      H {
        html5 {
          head {
            title 'הארץ בלי עניינים'
            meta charset: 'utf-8'
            meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
            meta name: 'referrer', content: 'no-referrer'
            style 'body { display: none }' # prevent FUOC
            link rel: 'stylesheet', href: '/assets/style.css', type: 'text/css'
          }
          body {
            h1 'הארץ בלי עניינים'
            
            last_date = nil
            context[:articles].each do |a|
              date = a[:stamp].to_date
              if date != last_date
                last_date = date
                h3 date.strftime('%d·%m·%Y'), class: 'date'
              end
              p {
                span a[:stamp].strftime('%H:%M'), class: 'time'
                a a[:title], href: a[:archive_uri], target: '_blank'
              }
            end
          }
        }
      }
    end

    FEED_URL = 'https://www.haaretz.co.il/cmlink/1.1470869'
    MAX_ARTICLE_AGE = 86400

    def article_list
      body = HTTParty.get(FEED_URL, timeout: 5).body

      doc = Nokogiri::XML(body)
      now = Time.now
      doc.css('item').map { |i|
        item_to_article(i)
      }.select { |a| 
        now - a[:stamp] < MAX_ARTICLE_AGE
      }
    rescue
      []
    end
    
    def item_to_article(item)
      uri = item.css('link').first.content
      {
        title: item.css('title').first.content,
        uri: uri,
        archive_uri: archive_uri(uri), 
        stamp: Time.parse(item.css('pubDate').first.content),
        author: item.css('author').first&.content,
        category: item.css('category').first&.content
      }
    end

    URLA = 'https://archive.today/?run=1&url='
    def archive_uri(uri)
      URLA + EscapeUtils.escape_uri(uri)
    end
  end
end
