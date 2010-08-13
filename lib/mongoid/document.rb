# encoding: utf-8
module Mongoid #:nodoc:
  module Document
    extend ActiveSupport::Concern
    included do
      include Mongoid::Components

      attr_accessor :association_name
      attr_reader :new_record
    end

    module ClassMethods #:nodoc:

      # Instantiate a new object, only when loaded from the database or when
      # the attributes have already been typecast.
      #
      # Example:
      #
      # <tt>Person.instantiate(:title => "Sir", :age => 30)</tt>
      def instantiate(attrs = nil, allocating = false)
        attributes = attrs || {}
        if attributes["_id"] || allocating
          document = allocate
          document.instance_variable_set(:@attributes, attributes)
          document.setup_modifications
          document
        else
          new(attrs)
        end
      end

      #battle with self-nest
      #bubble up parent to find it's place in the world
      def detect_self_nestedness
        if not embedded?  #this means it is not explicity embedded_in.
          found = false
          @pos = []
          @d = doc
          until found or not @d
            @pos << @d.association_name
            @d = doc._parent
            #debugger
            found_index = @d.associations.keys.index(doc.association_name)

            found = @d.associations[@d.associations.keys[found_index]].association ==  Mongoid::Associations::EmbedsMany if found_index
            ###
            # need to add a check for data type. for example,  
            #   if embeds_many :cats, then you cannot push a Dog 
            ###
            #if found 
            #  found = @d.associations.keys[found_index].singularize.downcase == doc.class.to_s.downcase
            #  raise Exception unless found 
            #end
          end
          #debugger
          puts "def _path; #{@pos.reverse.join(".")}; end"
          doc.instance_eval "def _path; \"#{@pos.reverse.join(".")}\"; end" if found
          doc.instance_eval "def self_nested?; #{found}; end"
        else
          doc.instance_eval "def self_nested?; false; end"
        end
      end

      # Returns all types to query for when using this class as the base.
      # *subclasses* is from activesupport. Note that a bug in *subclasses*
      # causes the first call to only return direct children, hence
      # the double call and unique.
      def _types
        @_type ||= [descendants + [self]].flatten.uniq.map(&:to_s)
      end
    end

    # Performs equality checking on the document ids. For more robust
    # equality checking please override this method.
    def ==(other)
      return false unless other.is_a?(Document)
      id == other.id
    end

    # Delegates to ==
    def eql?(comparison_object)
      self == (comparison_object)
    end

    # Delegates to id in order to allow two records of the same type and id to
    # work with something like:
    #   [ Person.find(1),
    #     Person.find(2),
    #     Person.find(3) ] &
    #   [ Person.find(1),
    #     Person.find(4) ] # => [ Person.find(1) ]
    def hash
      id.hash
    end

    # Introduces a child object into the +Document+ object graph. This will
    # set up the relationships between the parent and child and update the
    # attributes of the parent +Document+.
    #
    # Options:
    #
    # parent: The +Document+ to assimilate with.
    # options: The association +Options+ for the child.
    def assimilate(parent, options)
      parentize(parent, options.name); notify; self
    end

    # Return the attributes hash with indifferent access.
    def attributes
      @attributes.with_indifferent_access
    end

    # Clone the current +Document+. This will return all attributes with the
    # exception of the document's id and versions.
    def clone
      self.class.instantiate(@attributes.except("_id").except("versions").dup, true)
    end

    # Generate an id for this +Document+.
    def identify
      Identity.new(self).create
    end

    # Instantiate a new +Document+, setting the Document's attributes if
    # given. If no attributes are provided, they will be initialized with
    # an empty +Hash+.
    #
    # If a primary key is defined, the document's id will be set to that key,
    # otherwise it will be set to a fresh +BSON::ObjectID+ string.
    #
    # Options:
    #
    # attrs: The attributes +Hash+ to set up the document with.
    def initialize(attrs = nil)
      @attributes = default_attributes
      process(attrs)
      @new_record = true
      document = yield self if block_given?
      identify
      run_callbacks(:initialize) do
        document
      end
    end

    # Returns the class name plus its attributes.
    def inspect
      attrs = fields.map { |name, field| "#{name}: #{@attributes[name].inspect}" }
      if Mongoid.allow_dynamic_fields
        dynamic_keys = @attributes.keys - fields.keys - associations.keys - ["_id", "_type"]
        attrs += dynamic_keys.map { |name| "#{name}: #{@attributes[name].inspect}" }
      end
      "#<#{self.class.name} _id: #{id}, #{attrs * ', '}>"
    end

    # Notify parent of an update.
    #
    # Example:
    #
    # <tt>person.notify</tt>
    def notify
      _parent.update_child(self) if _parent
    end

    # Return the attributes hash.
    def raw_attributes
      @attributes
    end

    # Reloads the +Document+ attributes from the database.
    def reload
      reloaded = collection.find_one(:_id => id)
      if Mongoid.raise_not_found_error
        raise Errors::DocumentNotFound.new(self.class, id) if reloaded.nil?
      end
      @attributes = {}.merge(reloaded || {})
      self.associations.keys.each { |association_name| unmemoize(association_name) }; self
    end

    # Remove a child document from this parent +Document+. Will reset the
    # memoized association and notify the parent of the change.
    def remove(child)
      name = child.association_name
      if @building_nested
        @attributes.remove(name, child.raw_attributes)
      else
        reset(name) do
          @attributes.remove(name, child.raw_attributes)
          @attributes[name]
        end
        notify
      end
    end

    # def remove_without_reset
    #   name = child.association_name
    #   @attributes.remove(name, child.raw_attributes)
    #   notify
    # end

    # Return an array with this +Document+ only in it.
    def to_a
      [ self ]
    end

    # Recieve a notify call from a child +Document+. This will either update
    # existing attributes on the +Document+ or clear them out for the child if
    # the clear boolean is provided.
    #
    # Options:
    #
    # child: The child +Document+ that sent the notification.
    # clear: Will clear out the child's attributes if set to true.
    def update_child(child, clear = false)
      name = child.association_name
      attrs = child.instance_variable_get(:@attributes)
      if clear
        @attributes.delete(name)
      else
        # check good for array only
        @attributes.insert(name, attrs) unless @attributes[name] && @attributes[name].include?(attrs)
      end
    end
  end
end
