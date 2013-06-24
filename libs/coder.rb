module Autumn

  # Helper class that generates shell Ruby code. This class knows how to
  # generate Ruby code for template classes and methods.

  class Coder # :nodoc:
    # @return [String] The generated code string.
    attr :output

    # Creates a new instance with an indent level of 0 and an empty output
    # string.

    def initialize
      @indent = 0
      @output = String.new
    end

    # Creates a new class empty class. This method yields another Generator,
    # which you can populate with the contents of the class, if you wish.
    # Example:
    #
    # ```` ruby
    # gen.klass("Foo") { |foo| foo.method("bar") }
    # ````
    #
    # produces:
    #
    # ````
    #  class Foo
    #    def bar
    #    end
    #  end
    # ````
    #
    # @param [String] name The class name.
    # @param [String] superclass The superclass name, if any.
    # @yield [generator] Executes this block in the context of this class's
    #   contents.
    # @yieldparam [Coder] A Coder in the context of this class's contents.
    # @return [String] The class code.

    def klass(name, superclass=nil)
      if superclass
        self << "class #{name} < #{superclass}"
      else
        self << "class #{name}"
      end

      if block_given?
        generator = self.class.new
        yield generator
        indent!
        self << generator.output
        unindent!
      end

      self << 'end'

      return self
    end

    # Creates a new empty method. Any additional parameters are considered to be
    # the generated method's parameters. They can be symbols/strings (taken to
    # be the parameter's name), or hashes associating the parameter's name to
    # its default value.
    #
    # This method yields another Generator, which you can populate with the
    # contents of the method, if you wish. Example:
    #
    # ```` ruby
    # gen.method("test", :required, { optional: 'default' })
    # ````
    #
    # produces:
    #
    # ````
    # def test(required, optional="default")
    # end
    # ````
    #
    # @overload method(name, param1, ..., :param2 => default, ...)
    #   @param [String] name The method name.
    #   @param [String] param2 A parameter name (with no default).
    #   @param [String] param2 A parameter name (with default value).
    #   @param [Object] default A default value for the parameter.
    #   @yield [coder] Executes this block in the context of this class's
    #     contents.
    #   @yieldparam [Coder] coder A Coder in the context of this method's
    #     contents.
    #   @return [String] The method code.

    def method(name, *params)
      if params.empty?
        self << "def #{name}"
      else
        self << "def #{name}(#{parameterize params})"
      end

      if block_given?
        generator = self.class.new
        yield generator
        indent!
        self << generator.output
        unindent!
      end

      self << 'end'

      return self
    end

    # Increases the indent level for all future lines of code appended to this
    # Coder.

    def indent!
      @indent = @indent + 1
    end

    # Decreases the indent level for all future lines of code appended to this
    # Coder.

    def unindent!
      @indent = @indent - 1 unless @indent == 0
    end

    # Adds a line of code to this Generator, sequentially.
    #
    # @param [String] str The line of code.

    def <<(str)
      str.split(/\n/).each do |line|
        @output << "#{tab}#{line}\n"
      end
    end

    # Sets this method's documentation and prepends it to the output as a
    # comment.
    #
    # @param [String] str The method documentation.

    def doc=(str)
      doc_lines = str.line_wrap(80 - tab.size - 2).split("\n")
      doc_lines.map! { |l| "#{tab}# #{l}\n" }
      @output = doc_lines.join + "\n" + @output
    end

    # Appends a blank line to the output.

    def newline!
      @output << "\n"
    end

    private

    def parameterize(params)
      param_strs = Array.new
      params.each do |param|
        if param.kind_of? Hash && param.size == 1
          name    = param.keys.only
          default = param.values.only
          raise ArgumentError, "Invalid parameter #{name.inspect}" unless name.respond_to?(:to_s) && !name.to_s.empty?
          param_strs << "#{name.to_s}=#{default.inspect}"
        elsif param.respond_to?(:to_s) && !param.to_s.empty?
          param_strs << param.to_s
        else
          raise ArgumentError, "Invalid parameter #{param.inspect}"
        end
      end
      return param_strs.join(', ')
    end

    def tab
      '  ' * @indent
    end
  end

  # Generates Autumn-specific code templates like leaves and filters.

  class TemplateCoder < Coder # :nodoc:

    # Generates a Leaf subclass with the given name.
    #
    # @param [String] name The Leaf name.

    def leaf(name)
      controller     = klass('Controller', 'Autumn::Leaf') do |leaf|
        leaf.newline!
        leaf << '# Typing "!about" displays some basic information about this leaf.'
        leaf.newline!
        leaf.method('about_command', 'stem', 'sender', 'reply_to', 'msg') do |about|
          about << '# This method renders the file "about.txt.erb"'
        end
      end
      controller.doc = "Controller for the #{name.camelcase(:upper)} leaf."
      return controller
    end
  end
end
