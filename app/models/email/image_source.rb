# Turns an image setting into what an email needs: an absolute URL plus the size to
# show it at. Uploaded images are stored by reference (their Active Storage path) and
# resized server-side, since most email clients ignore CSS like object-fit:
#
#   fit     – scale to fit inside width × height, centred on the section background
#   center  – original size, centred in the box, trimmed or padded to fit
#   stretch – scaled to exactly width × height
#   crop    – scaled to fill width × height, trimming the overflow
#
# Images are rendered at 2× for sharp screens. Pasted URLs aren't ours to resize, so
# they're only given the width and height.
class Email::ImageSource
  MAX_WIDTH = 552 # the 600px email body minus section padding
  MAX_HEIGHT = 2000
  FITS = { "fit" => "Best fit", "center" => "Center", "stretch" => "Stretch", "crop" => "Crop" }.freeze
  BLOB_PATH = %r{/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/]+)/}
  RESIZABLE = %w[ image/jpeg image/png image/webp image/heic image/heif image/avif image/tiff ].freeze

  Result = Data.define(:url, :width, :height)

  # What's stored for an upload: a path, so the host (and dev port) is decided when rendering.
  def self.stored_value(blob) = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)

  def self.blob_for(value)
    signed_id = value.to_s[BLOB_PATH, 1] or return
    ActiveStorage::Blob.find_signed(signed_id)
  end

  def initialize(value, base_url:, width: nil, height: nil, fit: "fit", background: "#ffffff")
    @value = value.to_s.strip
    @base_url = base_url
    @width = width.to_i.positive? ? width.to_i.clamp(1, MAX_WIDTH) : nil
    @height = height.to_i.positive? ? height.to_i.clamp(1, MAX_HEIGHT) : nil
    @fit = FITS.key?(fit) ? fit : "fit"
    @background = background
  end

  def resolve
    return if @value.blank?

    blob = self.class.blob_for(@value)
    return Result.new(url: @value.match?(%r{\Ahttps?://}i) ? @value : nil, width: @width, height: @height) unless blob

    blob.analyze unless blob.analyzed?
    return Result.new(url: absolute(Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)), width: @width, height: @height) unless resizable?(blob)

    width, height, transformations = plan(blob.metadata["width"].to_i, blob.metadata["height"].to_i)
    variant = blob.variant(transformations.merge(format_for(blob)))
    Result.new(url: absolute(Rails.application.routes.url_helpers.rails_representation_path(variant, only_path: true)), width:, height:)
  end

  private
    def resizable?(blob) = RESIZABLE.include?(blob.content_type) && blob.metadata["width"].to_i.positive?

    # [display width, display height, Active Storage transformations]
    def plan(original_width, original_height)
      ratio = original_height.to_f / original_width

      if @width && @height
        box = [ @width * 2, @height * 2 ]
        transformations = case @fit
        when "crop" then { resize_to_fill: box }
        when "stretch" then { thumbnail_image: [ box.first, { height: box.last, size: :force } ] }
        when "center" then { gravity: [ "centre", @width, @height, { extend: :background, background: rgb } ] }
        else { resize_and_pad: [ *box, { background: rgb } ] }
        end
        [ @width, @height, transformations ]
      else
        width = @width || (@height ? (@height / ratio).round : original_width)
        width = width.clamp(1, MAX_WIDTH)
        height = (width * ratio).round
        [ width, height, { resize_to_fit: [ width * 2, height * 2 ] } ]
      end
    end

    # Email clients can't show HEIC and friends, so those become JPEGs.
    def format_for(blob) = %w[ image/jpeg image/png ].include?(blob.content_type) ? {} : { format: :jpg }

    def rgb
      hex = @background.to_s.match?(/\A#\h{6}\z/) ? @background : "#ffffff"
      hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    end

    def absolute(path) = "#{@base_url}#{path}"
end
