# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-03', '4-04', '4-05')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Parsing the template source code
        
        - **Prism** is the new Ruby parser
        - Source code in, AST out
        - Use `Proc#source_location` to get location of Proc (filename + lineno)
        - Parse file and find `LambdaNode` starting at correct line:

        ```ruby
        def proc_ast(proc)
          fn, lineno = proc.source_location
          pr = Prism.parse(get_source(fn), filepath: fn)
          program = pr.value
        
          Finder.find(program, proc) do
            on(:lambda) do |node|
              found!(node) if node.location.start_line == lineno
              super(node)
            end
          end
        rescue Errno::ENOENT
          raise Sirop::Error, "Could not get source for proc"
        end
        ```
      MD
    }
  }
}
