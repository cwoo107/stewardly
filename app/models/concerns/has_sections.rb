# An ordered list of sections stored as JSON (email templates, website pages): each is
# { "id", "key" (a SectionDefinition of this kind), "settings" }.
#
#   has_sections :sections, kind: "email"
module HasSections
  extend ActiveSupport::Concern

  class_methods do
    def has_sections(attribute, kind:)
      define_method(:sections_attribute) { attribute }
      define_method(:sections_kind) { kind }
      validate :sections_are_known
    end
  end

  def section_list = Array(self[sections_attribute])
  def section(id) = section_list.find { |section| section["id"] == id }
  def section_definitions = SectionDefinition::Defaults.sections(sections_kind)

  def add_section!(key, after: nil)
    definition = section_definitions.find_by!(key:)
    raise ArgumentError, "That section is added automatically" if definition.schema["system_only"]

    entry = { "id" => SecureRandom.alphanumeric(8), "key" => key, "settings" => definition.default_settings }
    list = section_list.dup
    index = after ? list.index { |section| section["id"] == after }&.succ : nil
    index ? list.insert(index, entry) : list << entry
    write_sections!(list)
    entry
  end

  def update_section!(id, settings)
    write_sections!(section_list.map { |section| section["id"] == id ? section.merge("settings" => settings) : section })
  end

  def remove_section!(id)
    write_sections!(section_list.reject { |section| section["id"] == id })
  end

  def move_section!(id, index)
    moving = section(id) or return
    rest = section_list.reject { |section| section["id"] == id }
    write_sections!(rest.insert(index.to_i.clamp(0, rest.size), moving))
  end

  private
    def write_sections!(list)
      update!(sections_attribute => list)
    end

    def sections_are_known
      known = SectionDefinition.where(kind: sections_kind).pluck(:key)
      unknown = section_list.map { |section| section["key"] } - known
      errors.add(sections_attribute, "include unknown kinds: #{unknown.uniq.to_sentence}") if unknown.any?
    end
end
