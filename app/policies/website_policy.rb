# Simple mode (pages, sections, theme settings) needs manage_website; advanced mode
# (Liquid, layout, custom sections, domains) needs develop_website.
class WebsitePolicy < ApplicationPolicy
  def show? = can?(:manage_website) || can?(:develop_website)
  def update? = show?
  def develop? = can?(:develop_website)
end
