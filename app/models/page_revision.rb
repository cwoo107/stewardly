# A snapshot of a page each time it's published (the last Page::REVISIONS_KEPT).
class PageRevision < ApplicationRecord
  belongs_to :page
  belongs_to :published_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church
end
