require "rails_helper"

RSpec.describe TaskPolicy do
  let(:owner) { create(:user, :care_team) }
  let(:task) { create(:task, owner:) }

  it "gives manage_tasks everything" do
    policy = described_class.new(create(:user, :staff), task)
    expect([ policy.index?, policy.create?, policy.update?, policy.move?, policy.destroy? ]).to all(be(true))
  end

  it "lets owners see and update their own tasks only" do
    task
    expect(described_class.new(owner, task).update?).to be(true)
    expect(described_class.new(owner, task).destroy?).to be(false)
    expect(described_class.new(owner, create(:task)).show?).to be(false)
    expect(described_class::Scope.new(owner, Task).resolve).to contain_exactly(task)
  end

  it "keeps users without tasks off the board" do
    expect(described_class.new(create(:user, :member), Task).index?).to be(false)
  end
end
