# Drag-and-drop ordering for Task (per status column), CustomField, and FormField
# (per form). New records go to the end of their list; #reposition renumbers the
# list in a single UPDATE.
#
#   positioned within: :status
module Positionable
  extend ActiveSupport::Concern

  included do
    class_attribute :position_scope, instance_writer: false, default: []
    before_create :append_to_list
    scope :ordered, -> { order(:position, :id) }
  end

  class_methods do
    def positioned(within: [])
      self.position_scope = Array(within).map(&:to_s)
    end
  end

  # Moves this record to a zero-based index among its siblings.
  def reposition(index)
    transaction do
      ids = list_siblings.where.not(id:).ordered.lock.pluck(:id)
      ids.insert(index.to_i.clamp(0, ids.size), id)
      self.class.where(id: ids).update_all([ "position = array_position(ARRAY[?]::bigint[], id) - 1", ids ])
    end
  end

  private
    def list_siblings
      self.class.where(attributes.slice(*position_scope))
    end

    def append_to_list
      self.position = (list_siblings.maximum(:position) || -1) + 1
    end
end
