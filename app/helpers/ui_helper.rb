# Shared Tailwind class lists taken from the Pocket style guide (Button.jsx, Fields.jsx),
# so forms and buttons look the same everywhere without custom CSS.
module UiHelper
  INPUT_CLASSES = "block w-full appearance-none rounded-lg border border-gray-200 bg-white py-[calc(--spacing(2)-1px)] " \
    "px-[calc(--spacing(3)-1px)] text-gray-900 placeholder:text-gray-400 focus:border-cyan-500 focus:outline-hidden " \
    "focus:ring-cyan-500 sm:text-sm".freeze

  LABEL_CLASSES = "mb-2 block text-sm font-semibold text-gray-900".freeze

  BUTTON_CLASSES = {
    primary: "inline-flex justify-center rounded-lg bg-cyan-500 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-cyan-600 active:text-white/80 cursor-pointer",
    secondary: "inline-flex justify-center rounded-lg bg-gray-800 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-gray-900 active:text-white/80 cursor-pointer",
    outline: "inline-flex justify-center rounded-lg border border-gray-300 px-[calc(--spacing(3)-1px)] py-[calc(--spacing(2)-1px)] text-sm text-gray-700 transition-colors hover:border-gray-400 active:bg-gray-100 cursor-pointer",
    danger: "inline-flex justify-center rounded-lg border border-red-200 px-[calc(--spacing(3)-1px)] py-[calc(--spacing(2)-1px)] text-sm text-red-700 transition-colors hover:border-red-300 hover:bg-red-50 cursor-pointer"
  }.freeze

  BADGE_COLORS = {
    "gray" => "bg-gray-100 text-gray-700", "cyan" => "bg-cyan-50 text-cyan-900", "green" => "bg-green-50 text-green-800",
    "amber" => "bg-amber-50 text-amber-800", "rose" => "bg-rose-50 text-rose-800", "violet" => "bg-violet-50 text-violet-800"
  }.freeze

  PRIORITY_COLORS = { "low" => "gray", "normal" => "cyan", "high" => "amber", "urgent" => "rose" }.freeze

  CARD_CLASSES = "rounded-4xl bg-white p-6 shadow-sm ring-1 ring-gray-200 sm:p-8".freeze

  def input_classes = INPUT_CLASSES
  def select_classes = "#{INPUT_CLASSES} pr-8"
  def label_classes = LABEL_CLASSES
  def card_classes = CARD_CLASSES
  def button_classes(variant = :primary) = BUTTON_CLASSES.fetch(variant)

  def badge(text, color: "gray")
    tag.span(text, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{BADGE_COLORS.fetch(color, BADGE_COLORS["gray"])}")
  end

  def tag_badge(tag) = badge(tag.name, color: tag.color)

  def priority_badge(task) = badge(task.priority.humanize, color: PRIORITY_COLORS.fetch(task.priority))
end
