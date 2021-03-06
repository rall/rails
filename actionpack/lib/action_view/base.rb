require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'

module ActionView #:nodoc:
  class ActionViewError < StandardError #:nodoc:
  end

  class MissingTemplate < ActionViewError #:nodoc:
    attr_reader :path, :action_name

    def initialize(paths, path, template_format = nil)
      @path = path
      @action_name = path.split("/").last.split(".")[0...-1].join(".")
      full_template_path = path.include?('.') ? path : "#{path}.erb"
      display_paths = paths.compact.join(":")
      template_type = (path =~ /layouts/i) ? 'layout' : 'template'
      super("Missing #{template_type} #{full_template_path} in view path #{display_paths}")
    end
  end

  # Action View templates can be written in three ways. If the template file has a <tt>.erb</tt> (or <tt>.rhtml</tt>) extension then it uses a mixture of ERb
  # (included in Ruby) and HTML. If the template file has a <tt>.builder</tt> (or <tt>.rxml</tt>) extension then Jim Weirich's Builder::XmlMarkup library is used.
  # If the template file has a <tt>.rjs</tt> extension then it will use ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.
  #
  # = ERb
  #
  # You trigger ERb by using embeddings such as <% %>, <% -%>, and <%= %>. The <%= %> tag set is used when you want output. Consider the
  # following loop for names:
  #
  #   <b>Names of all the people</b>
  #   <% for person in @people %>
  #     Name: <%= person.name %><br/>
  #   <% end %>
  #
  # The loop is setup in regular embedding tags <% %> and the name is written using the output embedding tag <%= %>. Note that this
  # is not just a usage suggestion. Regular output functions like print or puts won't work with ERb templates. So this would be wrong:
  #
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # If you absolutely must write from within a function, you can use the TextHelper#concat.
  #
  # <%- and -%> suppress leading and trailing whitespace, including the trailing newline, and can be used interchangeably with <% and %>.
  #
  # == Using sub templates
  #
  # Using sub templates allows you to sidestep tedious replication and extract common display structures in shared templates. The
  # classic example is the use of a header and footer (even though the Action Pack-way would be to use Layouts):
  #
  #   <%= render "shared/header" %>
  #   Something really specific and terrific
  #   <%= render "shared/footer" %>
  #
  # As you see, we use the output embeddings for the render methods. The render call itself will just return a string holding the
  # result of the rendering. The output embedding writes it to the current template.
  #
  # But you don't have to restrict yourself to static includes. Templates can share variables amongst themselves by using instance
  # variables defined using the regular embedding tags. Like this:
  #
  #   <% @page_title = "A Wonderful Hello" %>
  #   <%= render "shared/header" %>
  #
  # Now the header can pick up on the <tt>@page_title</tt> variable and use it for outputting a title tag:
  #
  #   <title><%= @page_title %></title>
  #
  # == Passing local variables to sub templates
  #
  # You can pass local variables to sub templates by using a hash with the variable names as keys and the objects as values:
  #
  #   <%= render "shared/header", { :headline => "Welcome", :person => person } %>
  #
  # These can now be accessed in <tt>shared/header</tt> with:
  #
  #   Headline: <%= headline %>
  #   First name: <%= person.first_name %>
  #
  # If you need to find out whether a certain local variable has been assigned a value in a particular render call,
  # you need to use the following pattern:
  #
  #   <% if local_assigns.has_key? :headline %>
  #     Headline: <%= headline %>
  #   <% end %>
  #
  # Testing using <tt>defined? headline</tt> will not work. This is an implementation restriction.
  #
  # == Template caching
  #
  # By default, Rails will compile each template to a method in order to render it. When you alter a template, Rails will
  # check the file's modification time and recompile it.
  #
  # == Builder
  #
  # Builder templates are a more programmatic alternative to ERb. They are especially useful for generating XML content. An XmlMarkup object
  # named +xml+ is automatically made available to templates with a <tt>.builder</tt> extension.
  #
  # Here are some basic examples:
  #
  #   xml.em("emphasized")                              # => <em>emphasized</em>
  #   xml.em { xml.b("emph & bold") }                   # => <em><b>emph &amp; bold</b></em>
  #   xml.a("A Link", "href"=>"http://onestepback.org") # => <a href="http://onestepback.org">A Link</a>
  #   xml.target("name"=>"compile", "option"=>"fast")   # => <target option="fast" name="compile"\>
  #                                                     # NOTE: order of attributes is not specified.
  #
  # Any method with a block will be treated as an XML markup tag with nested markup in the block. For example, the following:
  #
  #   xml.div {
  #     xml.h1(@person.name)
  #     xml.p(@person.bio)
  #   }
  #
  # would produce something like:
  #
  #   <div>
  #     <h1>David Heinemeier Hansson</h1>
  #     <p>A product of Danish Design during the Winter of '79...</p>
  #   </div>
  #
  # A full-length RSS example actually used on Basecamp:
  #
  #   xml.rss("version" => "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
  #     xml.channel do
  #       xml.title(@feed_title)
  #       xml.link(@url)
  #       xml.description "Basecamp: Recent items"
  #       xml.language "en-us"
  #       xml.ttl "40"
  #
  #       for item in @recent_items
  #         xml.item do
  #           xml.title(item_title(item))
  #           xml.description(item_description(item)) if item_description(item)
  #           xml.pubDate(item_pubDate(item))
  #           xml.guid(@person.firm.account.url + @recent_items.url(item))
  #           xml.link(@person.firm.account.url + @recent_items.url(item))
  #
  #           xml.tag!("dc:creator", item.author_name) if item_has_creator?(item)
  #         end
  #       end
  #     end
  #   end
  #
  # More builder documentation can be found at http://builder.rubyforge.org.
  #
  # == JavaScriptGenerator
  #
  # JavaScriptGenerator templates end in <tt>.rjs</tt>. Unlike conventional templates which are used to
  # render the results of an action, these templates generate instructions on how to modify an already rendered page. This makes it easy to
  # modify multiple elements on your page in one declarative Ajax response. Actions with these templates are called in the background with Ajax
  # and make updates to the page where the request originated from.
  #
  # An instance of the JavaScriptGenerator object named +page+ is automatically made available to your template, which is implicitly wrapped in an ActionView::Helpers::PrototypeHelper#update_page block.
  #
  # When an <tt>.rjs</tt> action is called with +link_to_remote+, the generated JavaScript is automatically evaluated.  Example:
  #
  #   link_to_remote :url => {:action => 'delete'}
  #
  # The subsequently rendered <tt>delete.rjs</tt> might look like:
  #
  #   page.replace_html  'sidebar', :partial => 'sidebar'
  #   page.remove        "person-#{@person.id}"
  #   page.visual_effect :highlight, 'user-list'
  #
  # This refreshes the sidebar, removes a person element and highlights the user list.
  #
  # See the ActionView::Helpers::PrototypeHelper::GeneratorMethods documentation for more details.
  class Base
    module Subclasses
    end

    include Helpers, Rendering, Partials, ::ERB::Util

    def config
      self.config = DEFAULT_CONFIG unless @config
      @config
    end

    def config=(config)
      @config = ActiveSupport::OrderedOptions.new.merge(config)
    end

    extend ActiveSupport::Memoizable

    attr_accessor :base_path, :assigns, :template_extension, :formats
    attr_accessor :controller
    attr_internal :captures

    def reset_formats(formats)
      @formats = formats

      if defined?(AbstractController::HashKey)
        # This is expensive, but we need to reset this when the format is updated,
        # which currently only happens
        Thread.current[:format_locale_key] =
          AbstractController::HashKey.get(self.class, formats, I18n.locale)
      end
    end

    class << self
      delegate :erb_trim_mode=, :to => 'ActionView::Template::Handlers::ERB'
      delegate :logger, :to => 'ActionController::Base', :allow_nil => true
    end

    @@debug_rjs = false
    ##
    # :singleton-method:
    # Specify whether RJS responses should be wrapped in a try/catch block
    # that alert()s the caught exception (and then re-raises it).
    cattr_accessor :debug_rjs

    # Specify whether templates should be cached. Otherwise the file we be read everytime it is accessed.
    # Automatically reloading templates are not thread safe and should only be used in development mode.
    @@cache_template_loading = nil
    cattr_accessor :cache_template_loading

    # :nodoc:
    def self.xss_safe?
      true
    end

    def self.cache_template_loading?
      ActionController::Base.allow_concurrency || (cache_template_loading.nil? ? !ActiveSupport::Dependencies.load? : cache_template_loading)
    end

    attr_internal :request, :layout

    def controller_path
      @controller_path ||= controller && controller.controller_path
    end

    delegate :request_forgery_protection_token, :template, :params, :session, :cookies, :response, :headers,
             :flash, :action_name, :controller_name, :to => :controller

    delegate :logger, :to => :controller, :allow_nil => true

    delegate :find, :to => :view_paths

    include Context

    def self.process_view_paths(value)
      ActionView::PathSet.new(Array(value))
    end

    extlib_inheritable_accessor :helpers
    attr_reader :helpers

    def self.for_controller(controller)
      @views ||= {}

      # TODO: Decouple this so helpers are a separate concern in AV just like
      # they are in AC.
      if controller.class.respond_to?(:_helper_serial)
        klass = @views[controller.class._helper_serial] ||= Class.new(self) do
          # Try to make stack traces clearer
          class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def self.name
              "ActionView for #{controller.class}"
            end

            def inspect
              "#<#{self.class.name}>"
            end
          ruby_eval

          if controller.respond_to?(:_helpers)
            include controller._helpers
            self.helpers = controller._helpers
          end
        end
      else
        klass = self
      end

      klass.new(controller.class.view_paths, {}, controller)
    end

    def initialize(view_paths = [], assigns_for_first_render = {}, controller = nil, formats = nil)#:nodoc:
      @formats = formats
      @assigns = assigns_for_first_render.each { |key, value| instance_variable_set("@#{key}", value) }
      @controller = controller
      @helpers = self.class.helpers || Module.new
      @_content_for = Hash.new {|h,k| h[k] = ActionView::SafeBuffer.new }
      self.view_paths = view_paths
    end

    attr_internal :template
    attr_reader :view_paths

    def view_paths=(paths)
      @view_paths = self.class.process_view_paths(paths)
    end

    def punctuate_body!(part)
      flush_output_buffer
      response.body_parts << part
      nil
    end

    # Evaluates the local assigns and controller ivars, pushes them to the view.
    def _evaluate_assigns_and_ivars #:nodoc:
      if @controller
        variables = @controller.instance_variable_names
        variables -= @controller.protected_instance_variables if @controller.respond_to?(:protected_instance_variables)
        variables.each { |name| instance_variable_set(name, @controller.instance_variable_get(name)) }
      end
    end

  end
end
