require "rails_helper"

RSpec.describe Pathway::Funnel do
  let(:pathway) { Pathway.current }
  let(:connect) { pathway.stages.first }
  let(:grow) { pathway.stages.second }
  let(:serve) { pathway.stages.third }

  def history(person, *steps)
    previous = nil
    steps.each do |stage, days_ago|
      create(:pathway_transition, person:, from_stage: previous, to_stage: stage, direction: previous ? "forward" : "placed", occurred_at: days_ago.days.ago)
      previous = stage
    end
    create(:pathway_placement, person:, pathway_stage: previous, entered_at: steps.last.last.days.ago)
  end

  before do
    history(create(:person), [ connect, 300 ], [ grow, 240 ], [ serve, 100 ]) # 60 days in Connect, 140 in Grow
    history(create(:person), [ connect, 200 ], [ grow, 180 ])                 # 20 days in Connect
    history(create(:person), [ connect, 150 ])                                # stuck (limit 90)
    history(create(:person), [ connect, 30 ])
  end

  subject(:funnel) { described_class.new(pathway) }

  it "counts people at each stage" do
    expect(funnel.counts.transform_keys(&:name)).to eq("Connect" => 2, "Grow" => 1, "Serve" => 1)
  end

  it "reports conversion and median time for each stage but the last" do
    expect(funnel.conversions[connect]).to eq(entered: 4, moved_on: 2, percent: 50)
    expect(funnel.conversions[grow]).to eq(entered: 2, moved_on: 1, percent: 50)
    expect(funnel.conversions).not_to have_key(serve)
    expect(funnel.median_days[grow]).to eq(140)
    expect(funnel.median_days[connect]).to eq(60) # [20, 60] → upper middle
  end

  it "lists people stuck past their stage's limit, never at the last stage" do
    expect(funnel.stuck.map { |p| p.pathway_stage.name }).to eq([ "Connect" ])
    serve.update!(stuck_after_days: 30)
    expect(funnel.stuck.count).to eq(1)
  end

  it "counts moves forward and back by month" do
    movement = funnel.movement
    expect(movement.keys).to eq(%w[ Forward Back ])
    expect(movement["Forward"].values.sum).to eq(3)
  end
end
