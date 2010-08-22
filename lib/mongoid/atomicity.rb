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
        child.embedded_many_for_real
        child._pushes.each do |attr, val|
          attr = val[:_path][0,val[:_path].rindex(".")]
          if updates[target].has_key?(child._parent._id)
            updates[target][child._parent._id] << {attr => [val]}
          else
             updates[target].update(child._parent._id => [{attr => [val]}])
          end
        end
        updates
      end.delete_if do |key, value|
        value.empty?
      end
    end

    protected
    # Get all the push attributes that need to occur.
    def _pushes
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
