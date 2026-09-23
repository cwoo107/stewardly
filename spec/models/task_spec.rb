require "rails_helper"

RSpec.describe Task do
  it_behaves_like "a tenant-scoped model"

  it "appends new tasks to the bottom of their column" do
    first = create(:task)
    second = create(:task)
    expect([ first.position, second.position ]).to eq([ 0, 1 ])
  end

  describe "#move_to" do
    it "moves a task between columns and renumbers the destination" do
      a, b = create_list(:task, 2, status: "in_progress")
      moving = create(:task, status: "todo")

      moving.move_to(status: "in_progress", position: 1)

      expect(Task.in_progress.ordered).to eq([ a, moving, b ])
      expect(Task.in_progress.ordered.map(&:position)).to eq([ 0, 1, 2 ])
    end

    it "clamps positions past the end" do
      a = create(:task)
      b = create(:task)
      a.move_to(status: "todo", position: 99)
      expect(Task.todo.ordered).to eq([ b, a ])
    end
  end

  it "stamps and clears completed_at as it moves in and out of done" do
    task = create(:task)
    task.update!(status: "done")
    expect(task.completed_at).to be_present
    task.update!(status: "todo")
    expect(task.completed_at).to be_nil
  end

  it "knows when it's overdue in the church's time zone" do
    today = church.today
    expect(build(:task, due_on: today - 1).overdue?(today)).to be(true)
    expect(build(:task, due_on: today - 1, status: "done").overdue?(today)).to be(false)
    expect(build(:task, due_on: today).overdue?(today)).to be(false)
  end

  it "keeps recently finished tasks on the board and drops old ones" do
    recent = create(:task, status: "done")
    old = create(:task, status: "done")
    old.update_column(:completed_at, 31.days.ago)
    expect(Task.on_board).to include(recent)
    expect(Task.on_board).not_to include(old)
  end
end
