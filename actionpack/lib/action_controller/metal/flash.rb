module ActionController #:nodoc:
  # The flash provides a way to pass temporary objects between actions. Anything you place in the flash will be exposed
  # to the very next action and then cleared out. This is a great way of doing notices and alerts, such as a create
  # action that sets <tt>flash[:notice] = "Successfully created"</tt> before redirecting to a display action that can
  # then expose the flash to its template. Actually, that exposure is automatically done. Example:
  #
  #   class PostsController < ActionController::Base
  #     def create
  #       # save post
  #       flash[:notice] = "Successfully created post"
  #       redirect_to posts_path(@post)
  #     end
  #
  #     def show
  #       # doesn't need to assign the flash notice to the template, that's done automatically
  #     end
  #   end
  #
  #   show.html.erb
  #     <% if flash[:notice] %>
  #       <div class="notice"><%= flash[:notice] %></div>
  #     <% end %>
  #
  # This example just places a string in the flash, but you can put any object in there. And of course, you can put as
  # many as you like at a time too. Just remember: They'll be gone by the time the next action has been performed.
  #
  # See docs on the FlashHash class for more details about the flash.
  module Flash
    extend ActiveSupport::Concern

    included do
      helper_method :alert, :notice
    end

    class FlashNow #:nodoc:
      def initialize(flash)
        @flash = flash
      end

      def []=(k, v)
        @flash[k] = v
        @flash.discard(k)
        v
      end

      def [](k)
        @flash[k]
      end
    end

    class FlashHash < Hash
      def initialize #:nodoc:
        super
        @used = Set.new
      end

      def []=(k, v) #:nodoc:
        keep(k)
        super
      end

      def update(h) #:nodoc:
        h.keys.each { |k| keep(k) }
        super
      end

      alias :merge! :update

      def replace(h) #:nodoc:
        @used = Set.new
        super
      end

      # Sets a flash that will not be available to the next action, only to the current.
      #
      #     flash.now[:message] = "Hello current action"
      #
      # This method enables you to use the flash as a central messaging system in your app.
      # When you need to pass an object to the next action, you use the standard flash assign (<tt>[]=</tt>).
      # When you need to pass an object to the current action, you use <tt>now</tt>, and your object will
      # vanish when the current action is done.
      #
      # Entries set via <tt>now</tt> are accessed the same way as standard entries: <tt>flash['my-key']</tt>.
      def now
        FlashNow.new(self)
      end

      # Keeps either the entire current flash or a specific flash entry available for the next action:
      #
      #    flash.keep            # keeps the entire flash
      #    flash.keep(:notice)   # keeps only the "notice" entry, the rest of the flash is discarded
      def keep(k = nil)
        use(k, false)
      end

      # Marks the entire flash or a single flash entry to be discarded by the end of the current action:
      #
      #     flash.discard              # discard the entire flash at the end of the current action
      #     flash.discard(:warning)    # discard only the "warning" entry at the end of the current action
      def discard(k = nil)
        use(k)
      end

      # Mark for removal entries that were kept, and delete unkept ones.
      #
      # This method is called automatically by filters, so you generally don't need to care about it.
      def sweep #:nodoc:
        keys.each do |k|
          unless @used.include?(k)
            @used << k
          else
            delete(k)
            @used.delete(k)
          end
        end

        # clean up after keys that could have been left over by calling reject! or shift on the flash
        (@used - keys).each{ |k| @used.delete(k) }
      end

      def store(session)
        return if self.empty?
        session["flash"] = self
      end

    private
      # Used internally by the <tt>keep</tt> and <tt>discard</tt> methods
      #     use()               # marks the entire flash as used
      #     use('msg')          # marks the "msg" entry as used
      #     use(nil, false)     # marks the entire flash as unused (keeps it around for one more action)
      #     use('msg', false)   # marks the "msg" entry as unused (keeps it around for one more action)
      # Returns the single value for the key you asked to be marked (un)used or the FlashHash itself
      # if no key is passed.
      def use(key = nil, used = true)
        Array(key || keys).each { |k| used ? @used << k : @used.delete(k) }
        return key ? self[key] : self
      end
  end

  # Access the contents of the flash. Use <tt>flash["notice"]</tt> to
  # read a notice you put there or <tt>flash["notice"] = "hello"</tt>
  # to put a new one.
  def flash #:doc:
    unless @_flash
      @_flash = session["flash"] || FlashHash.new
      @_flash.sweep
    end

    @_flash
  end

  # Convenience accessor for flash[:alert]
  def alert
    flash[:alert]
  end

  # Convenience accessor for flash[:alert]=
  def alert=(message)
    flash[:alert] = message
  end

  # Convenience accessor for flash[:notice]
  def notice
    flash[:notice]
  end

  # Convenience accessor for flash[:notice]=
  def notice=(message)
    flash[:notice] = message
  end


  protected
    def process_action(method_name)
      @_flash = nil
      super
      @_flash.store(session) if @_flash
      @_flash = nil
    end

    def reset_session
      super
      @_flash = nil
    end

    def redirect_to(options = {}, response_status_and_flash = {}) #:doc:
      if alert = response_status_and_flash.delete(:alert)
        flash[:alert] = alert
      end

      if notice = response_status_and_flash.delete(:notice)
        flash[:notice] = notice
      end

      if other_flashes = response_status_and_flash.delete(:flash)
        flash.update(other_flashes)
      end

      super(options, response_status_and_flash)
    end
  end
end
