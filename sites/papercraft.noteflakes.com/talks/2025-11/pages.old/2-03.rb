# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('2-02', '2-03', '2-04')

  h3 "Chainable methods / fluent interface"

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        # ala Sequel
        DB[:users]
          .select(:id, :name, :email)
          .where(country: 'France')
          .order_by(:name)
          .limit(10)
        ```

        - Each method returns a new object
        - Very simple technique
        - Mutation = performance penalty
        - No metaprogramming
      MD
    }

    div {
      markdown <<~MD
        ```ruby
        class Dataset
          def select(*fields)
            mutate(select: fields)
          end

          def order_by(expr)
            mutate(order_by: expr)
          end
          ...

          def mutate(**opts)
            self.class.new(@opts.merge(opts))
          end
        end
        ```
      MD
    }
  }
}
