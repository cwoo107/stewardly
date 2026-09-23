# Turns a submitted settings form into a section's stored settings: only ids the schema
# defines, typed values, uploaded images stored in Active Storage, and repeatable blocks
# added or removed ("add block" / "remove block" submit buttons).
class EmailTemplate::SectionSettings
  def initialize(definition, current)
    @definition = definition
    @current = current.to_h
  end

  def apply(params, block_action: nil)
    params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    settings = @definition.settings_schema.to_h { |setting| [ setting["id"], cast(setting, value_for(setting, params), @current[setting["id"]]) ] }

    if (blocks_schema = @definition.blocks_schema)
      blocks = Array(params["blocks"].is_a?(Hash) ? params["blocks"].sort_by { |key, _| key.to_i }.map(&:last) : params["blocks"])
      current_blocks = Array(@current["blocks"])
      blocks = blocks.each_with_index.map do |block, index|
        block = block.respond_to?(:to_unsafe_h) ? block.to_unsafe_h : block.to_h
        blocks_schema["settings"].to_h { |setting| [ setting["id"], cast(setting, value_for(setting, block), current_blocks[index].to_h[setting["id"]]) ] }
      end
      case block_action.to_s
      when "add" then blocks << blocks_schema["settings"].to_h { |setting| [ setting["id"], setting["default"] ] }
      when /\Aremove_(\d+)\z/ then blocks.delete_at(Regexp.last_match(1).to_i)
      end
      settings["blocks"] = blocks
    end
    settings
  end

  private
    # Image settings arrive as an upload (id), a pasted URL (id_url), the current upload
    # to keep (id_keep), or a request to remove it (id_remove).
    def value_for(setting, params)
      id = setting["id"]
      return params[id] unless setting["type"] == "image"
      return params[id] if params[id].respond_to?(:content_type)
      return params["#{id}_url"] if params["#{id}_url"].present?
      return "" if params["#{id}_remove"] == "1"

      params["#{id}_keep"].presence || params["#{id}_url"]
    end

    def cast(setting, value, current)
      case setting["type"]
      when "number" then value.presence&.to_i&.clamp(setting["min"] || -Float::INFINITY, setting["max"] || Float::INFINITY)
      when "checkbox" then value == "1"
      when "color" then value.to_s.match?(/\A#\h{6}\z/) ? value : nil
      when "select" then Array(setting["options"]).include?(value) ? value : setting["default"]
      when "url" then value.to_s.strip.match?(%r{\A(https?://|mailto:)}i) ? value.to_s.strip : nil
      when "image" then image_url(value, current)
      when "form" then Form.where(status: "published", access: "public").exists?(slug: value.to_s) ? value.to_s : nil
      else value.to_s.presence
      end
    end

    # A new upload is stored by reference (its path, so the host is decided when rendering).
    # Otherwise keep a pasted https URL or one of our own uploads.
    def image_url(value, current)
      if value.respond_to?(:content_type)
        return current unless value.content_type.to_s.start_with?("image/")

        blob = ActiveStorage::Blob.create_and_upload!(io: value, filename: value.original_filename, content_type: value.content_type)
        blob.analyze
        Email::ImageSource.stored_value(blob)
      elsif value.nil?
        current
      elsif (blob = Email::ImageSource.blob_for(value))
        Email::ImageSource.stored_value(blob)
      elsif value.to_s.strip.match?(%r{\Ahttps?://}i)
        value.to_s.strip
      end
    end
end
