# encoding: utf-8
module Mongoid #:nodoc:
  module Atomicity #:nodoc:
    extend ActiveSupport::Concern

    # Get all the atomic updates that need to happen for the current
    # +Document+. This includes all changes that need to happen in the
    # entire hierarchy that exists below where the save call was made.
    #
    # Example:
    #
    # <tt>person.save</tt> # Saves entire tree
    #
    # Returns:
    #
    # A +Hash+ of all atomic updates that need to occur.
    def _updates
      processed = {}
      _children.inject({ "$set" => _sets, "$pushAll" => {}, :other => {} }) do |updates, child|
        changes = child._sets
        updates["$set"].update(changes)
        processed[child.class] = true unless changes.empty?
        
        target = processed.has_key?(child.class) ? :other : "$pushAll"
        debugger if child.class == Essay
        child.build_hash_path
        child._pushes.each do |attr, val|

          @path ||= ""
          #build out a chain from the root so $pushAll puts it in the right place
          if child._parent
            #bubble up
            @d = child
            #debugger if child.class == Essay
            while false and @d
            end
            @path = val
          else
            @path = val
          end
          
          #debugger
          attr = @path[:_path][0,@path[:_path].rindex(".")]
          if updates[target].has_key?(child._parent._id)
            updates[target][child._parent._id] << {attr => [@path]}
          else
             updates[target].update(child._parent._id => [{attr => [@path]}])
          end
          #debugger if child.class == Essay

        end
        updates
      end.delete_if do |key, value|
        value.empty?
      end
    end

    protected
    # Get all the push attributes that need to occur.
    def _pushes
      debugger if self.class == Essay
      (new_record? && embedded_many? && !_parent.new_record?) ? { (_path.is_a?(Array) ? _path.last[_id] : _path) => raw_attributes } : {}
      #(new_record? && (embedded_many? || self_nested) && !_parent.new_record?) ? { use_path => raw_attributes } : {}
      
    end

    # Get all the attributes that need to be set.
    def _sets
      if changed? && !new_record?
        setters
      else
        embedded_one? && new_record? ? { _path => raw_attributes } : {}
      end
    end
  end
end
