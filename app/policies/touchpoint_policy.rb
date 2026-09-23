class TouchpointPolicy < ApplicationPolicy
  # Anyone who can see people can log a contact with them.
  def create? = can?(:view_people)

  # Sensitive touchpoints (prayer follow-ups) show their body only to the prayer team and pastors.
  def show_body? = !record.sensitive? || can?(:view_prayer_requests) || can?(:manage_prayer_requests)
end
