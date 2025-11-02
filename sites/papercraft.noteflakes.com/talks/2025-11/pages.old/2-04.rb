# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('2-03', '2-04', '2-05')

  h3 "Receiver-less block / builder pattern"

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        DB[:users].query do
          select :id, :name, :email
          where country: 'France'
          order_by :name
          limit 10
        end
        ```

        - builder pattern: configure an object with method calls inside a block.
        - Reads even better than chainable methods
        - Less allocations = better performance
        - Still no metaprogramming!
      MD
    }

    div {
      markdown <<~MD
        ```ruby
        class Dataset
          class Builder
            def initialize(opts, &block)
              @opts = opts
              instance_eval(&block)
            end

            def select(*fields)
              @opts[:select] = fields
            end
            ...
          end

          def query(&block)
            builder = Builder.new(@opts, &block)
            self.class.new(builder.opts)
          end
        end
        ```
      MD
    }
  }
}
