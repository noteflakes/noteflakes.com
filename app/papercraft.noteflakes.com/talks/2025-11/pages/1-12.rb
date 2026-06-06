# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-11', '1-12', '1-13')

  h3 'Code generation: file-based routing'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```bash
        # directory structure
        + site/
          + about.md
          + api+.rb
          + index.rb
          + posts/
            + index.rb
            + [id]/
              + index.rb
        ```

        - Directory structure is the URL structure.
        - Support for wildcard & parametric routes.
        - Route info stored in hashes.
        - Generated router proc parses URL path and returns route entry.
        - ~2x faster than Roda.

      MD
    }
    div {
      markdown <<~MD
        ```ruby
        # generated router code
        ->(path, params) {
          r = @static_map[path]; return r if r

          parts = path.split("/")
          case (p = parts[1])
          when "api"
            return @dynamic_map["/api+"]
          when "posts"
            case (p = parts[2])
            when p
              params["id"] = p
              case (p = parts[3])
              when nil
                return @dynamic_map["/posts/[id]"]
              end
            end
          end
          return nil
        }
        ```
      MD
    }
  }
}
