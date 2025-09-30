require 'syntropy/connection_pool'
require 'securerandom'
require 'json'

class Collection
  attr_reader :root

  def initialize(machine, env, dir)
    @machine = machine
    @env = env
    @dir = dir
    @root = read_collection
    @map = compute_file_map
    setup_search_db
  end

  def [](path)
    @map[path].tap { it[:headings] ||= get_entry_headings(it) }
  end

  SEARCH_SQL = <<~SQL
    select href, snippet(pages, -1, '>>>>>>>>', '<<<<<<<<', '...', 8) as snippet from pages where title match ? or body match ? order by rank;
  SQL

  def search(term)
    @db_conn.query(SEARCH_SQL, term, term)
  end

  def default_path
    first_file_entry[:href]
  end

  private

  def read_collection
    make_dir_entry(@dir)
  end

  def make_dir_entry(fn)
    name = File.basename(fn)
    title = entry_title(name)
    children = dir_entries(fn)

    {
      kind:     :directory,
      path:     fn,
      name:     name,
      title:    title,
      children: children.each_with_object({}) { |e, h| h[e[:name]] = e }
    }
  end

  def make_file_entry(fn)
    case File.extname(fn)
    when '.md'
      name = File.basename(fn)
      atts, markdown = Syntropy.parse_markdown_file(fn, @env)
      href = entry_href(fn)
      {
        kind:   :markdown,
        path:   fn,
        name:   name,
        title:  atts[:title] || entry_title(name),
        href:   href,
        markdown: markdown,
        html:   Papercraft.markdown(markdown)
      }
    else
      nil
    end
  end

  def dir_entries(dir)
    Dir[File.join(dir, '*')].map { |fn|
      next if File.basename(fn) =~ /^_/
        
      if File.directory?(fn)
        make_dir_entry(fn)
      else
        make_file_entry(fn)
      end
    }.compact
  end

  def entry_title(name)
    name
      .gsub(/^\d+\-/, '')
      .gsub(/\.md$/, '')
      .split('-').map {
        it.gsub(/^\w/) { |c| c.upcase }
      }
      .join(' ')
  end

  def entry_href(fn)
    ext = File.extname(fn)
    fn.match(/^#{Regexp.escape(@dir)}(.+)#{Regexp.escape(ext)}$/)[1]
  end

  def visit_entries(ptr, &block)
    ptr[:children].each_value {
      block.(it)
      if it[:kind] == :directory
        visit_entries(it, &block)
      end
    }
  end

  def each_file_entry(&block)
    visit_entries(@root) { block.(it) if it[:kind] != :directory }
  end

  def first_file_entry
    each_file_entry { return it }
    nil
  end

  def compute_file_map
    {}.tap { |map| each_file_entry { map[it[:href]] = it } }
  end

  def setup_search_db
    db_fn = File.join(@dir, '_search.db')
    @db_conn = Syntropy::ConnectionPool.new(@machine, db_fn, 2)
    validate_search_db_schema
    update_search_db_entries
  end

  def validate_search_db_schema
    @db_conn.execute <<~SQL
      create virtual table if not exists pages using fts5(path, href, mtime, title, body);
    SQL
  end

  def update_search_db_entries
    @db_conn.with_db do |db|
      db.transaction do
        visit_entries(@root) {
          update_search_db_entry(db, it) if it[:kind] != :directory
        }
      end
    end
  end

  def update_search_db_entry(db, entry)
    path = entry[:path]
    entry[:mtime] ||= fn_mtime(path)
    old = db.query_single("select * from pages where path = ?", path)
    if !old
      db.execute(
        "insert into pages (path, href, mtime, title, body) values (?, ?, ?, ?, ?)",
        path, entry[:href], entry[:mtime], entry[:title], entry[:markdown]
      )
    elsif old[:mtime] != entry[:mtime]
      db.execute(
        "update pages set mtime = ?, title = ?, body = ? where path = ?",
        entry[:mtime], entry[:title], entry[:markdown], path
      )
    end
  end

  def fn_mtime(fn)
    @machine.statx(UM::AT_FDCWD, fn, 0, UM::STATX_ALL)[:mtime].to_i
  end

  # Returns an array containing headings for the given document entry. Each
  # heading entry is an array containing the heading text and the heading id.
  def get_entry_headings(entry)
    # TODO: replace with Papercraft.markdown_doc(...) (when entry is first loaded)
    doc = Kramdown::Document.new(entry[:markdown])
    html_converter = Kramdown::Converter::Html.send(:new, doc.root, doc.options)
    
    kramdown_collect(doc.root, []) do |element, arr|
      if element.type == :header && element.options[:level] == 2
        title = element.options[:raw_text]
        arr << [title, html_converter.generate_id(title)]
      end
    end
  end

  # Visits each element in the given element subtree, yielding the given element
  # and all of its children, returning the given object.
  #
  # @param ptr [Kramdown::Element] element pointer
  # @param object [any] collector object
  # @return [any] collector object
  def kramdown_collect(ptr, object, &block)
    block.(ptr, object)
    ptr.children&.each { kramdown_collect(it, object, &block) }
    object
  end
end




Layout = import '_layout/default'
Pages = Collection.new(@machine, @env, File.join(__dir__, '_pages'))

export ->(req) {
  path = req.path
  path = path.gsub(/^#{Regexp.escape(@ref)}/, '') if @ref != '/'
  
  case path
  when '/'
    return req.redirect(Pages.default_path)
  when '/search'
    results = Pages.search(req.query[:s])
    return req.respond(JSON.dump(results), 'Content-Type' => Qeweney::MimeTypes[:json])
  end

  entry = Pages[path]
  if entry
    html = Layout.render(pages: Pages, path:, entry:)
    req.respond(html, 'Content-Type' => Qeweney::MimeTypes[:html])
  else
    # Pages[:entry_map].inspect
    req.respond(path)
  end
}
