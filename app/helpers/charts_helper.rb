# Chart styling shared by every chart (Chartkick on Chart.js). Series colors are
# assigned in a fixed order from a palette validated for color-blind separation;
# thin 2px lines, small points, recessive grid. Every chart ships with a data table.
module ChartsHelper
  SERIES_COLORS = %w[ #2a78d6 #eb6834 #1baf7a ].freeze # blue, orange, aqua (validated; aqua needs the table view)

  CHART_LIBRARY = {
    elements: { line: { borderWidth: 2, tension: 0.25 }, point: { radius: 0, hoverRadius: 5, hitRadius: 12 }, bar: { borderRadius: 4 } },
    interaction: { mode: "index", intersect: false },
    plugins: { legend: { position: "top", align: "start", labels: { boxWidth: 12, color: "#52514e" } } },
    scales: { x: { grid: { display: false }, ticks: { color: "#6b7280", maxTicksLimit: 8 } },
              y: { grid: { color: "#f3f4f6" }, ticks: { color: "#6b7280" }, beginAtZero: false } }
  }.freeze

  # Line charts don't need a zero baseline; the level is the point.
  def line_chart_options(**options)
    chart_options(min: nil, **options)
  end

  # Solid fills with a 2px gap between bars, instead of Chart.js's translucent fill and border.
  def column_chart_options(colors: SERIES_COLORS, **options)
    chart_options(colors:, dataset: { borderWidth: 0, borderSkipped: "start" },
      library: { datasets: { bar: { categoryPercentage: 0.8, barPercentage: 0.9 } } }, **options)
  end

  # Chartkick fills bars with a translucent version of each color; give each series its solid color.
  def solid_series(series, colors: SERIES_COLORS)
    series.each_with_index.map { |entry, index| entry.merge(dataset: { backgroundColor: colors[index], borderWidth: 0 }) }
  end

  def chart_options(colors: SERIES_COLORS, **options)
    { colors:, library: CHART_LIBRARY, thousands: ",", height: "260px" }.deep_merge(options)
  end
end
