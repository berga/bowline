module Bowline
  module Binders
    class Base
      cattr_accessor :params
    
      class << self
        # See Bowline::js
        def js
          Bowline::js
        end
      
        # Equivalent of the 'jQuery' function
        def jquery
          @@jquery ||= JQuery.new
        end
      
        # See the Observer class
        def observer
          @@observer ||= Observer.new
        end
        
        # See Bowline::logger
        def logger
          Bowline::logger
        end
      
        # See Bowline::show_view
        def show_view(*args)
          Bowline::show_view(*args)
        end
      
        def params=(p)
          case p
          when String
            # Params comes in a string (since it's a
            # serialized form) - we need to make it into
            # a nestled hash.
            # Stolen from Ramaze
            m = proc {|_,o,n|o.merge(n,&m)}
            @@params = params.inject({}) do |hash, (key, value)|
              parts = key.split(/[\]\[]+/)
              hash.merge(parts.reverse.inject(value) { |x, i| {i => x} }, &m) 
            end
          else
            @@params = p
          end
        end
      
        def setup(d)
          @@elements ||= []
          @@elements << d
          self.item_sync!
        end
      
        def instance(el)
          self.new(el).method(:send)
        end
      
        # todo - flash?
      
        def inherited(child)
          return if self == Bowline::Binders::Base
          return if child == Bowline::Binders::Singleton
          return if child == Bowline::Binders::Collection
          name = child.name.underscore
          name = name.split('/').last
          js.send("bowline_#{name}_setup=",    child.method(:setup))
          js.send("bowline_#{name}_instance=", child.method(:instance))
          js.send("bowline_#{name}=",          child.method(:send))
        end    
      end
    
      attr_reader :element
      attr_reader :item
    
      # Todo
      # We want initialize method to take
      # no argument, and for every item in items
      # to have initialize called on startup,
      # so they can set up event handlers etc
      def self.new(element, *args) #:nodoc:
        allocate.instance_eval do
          # jQuery element
          @element = element
          # Calling chain.js 'item' function
          @item    = element.item()
          if @item
            @item.with_indifferent_access
            # If possible, find Ruby object
            if @item[:id] && respond_to?(:find)
              @item = find(@item[:id])
            end
          end
        
          initialize(*args)
          self
        end
      end    

      # Trigger jQuery events on this element
      def trigger(event, data = nil)
        self.element.trigger(event, data)
      end
    
      # Bind event to element:
      # bind(:click) { puts "element clicked" }
      # todo - two events with the same item/event overwrite each other
      # todo - need initalize method on class - so we can set events there
      def bind(event, method_name, &block)
        event_name = [event, item_id].join(":")
        callback = block
        callback ||= begin
          method_name.is_a?(Method) ? 
            method_name : method(method_name)
        end
        self.observer.append(event_name, callback)
        self.element.bind(
          event.to_s, 
          event_name, 
          self.observer.method(:call)
        )
      end
    
      def click(method_name = nil, &block)
        bind(:click, method, &block)
      end
    
      # Raw DOM element
      def dom
        self.element[0]
      end
    
      # Shortcut methods
    
      # See self.class.show_view
      def show_view(*args)
        self.class.show_view(*args)
      end
    
      # See self.class.js
      def js
        self.class.js
      end
      alias :page :js
    
      # See self.class.jquery
      def jquery
        self.class.jquery
      end
    
      # See self.class.observer
      def observer
        self.class.observer
      end
      
      # See self.class.logger
      def logger
        self.class.logger
      end
    
      private
        # This is just a unique identifier
        # for the item - and isn't
        # used in the dom
        def item_id
          if item.respond_to?(:dom_id)
            item.dom_id
          else
            [
              item.id, 
              self.class.name.underscore
            ].join("_")
          end
        end
    end
  end
end