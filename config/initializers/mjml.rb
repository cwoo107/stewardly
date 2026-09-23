# MJML is compiled by MRML (the Rust implementation, via the mrml gem): no Node.
Mjml.setup do |config|
  config.use_mrml = true
  config.raise_render_exception = true
end
