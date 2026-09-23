require "rails_helper"

RSpec.describe "Tasks" do
  let(:staff) { create(:user, :staff) }

  context "as staff" do
    before { sign_in_as(staff) }

    it "shows the board with low-priority ideas parked" do
      create(:task, title: "Order packets", status: "todo")
      create(:task, title: "Big idea", status: "idea", priority: "normal")
      create(:task, title: "Someday maybe", status: "idea", priority: "low")

      get tasks_path
      expect(response.body).to include("Order packets", "Big idea", "Show 1 low-priority idea")
      expect(response.body).not_to include("Someday maybe")

      get tasks_path(show_low_ideas: "1")
      expect(response.body).to include("Someday maybe")
    end

    it "shows a filtered list view" do
      create(:task, title: "Late one", due_on: church.today - 2)
      create(:task, title: "On time", due_on: church.today + 2)
      get tasks_path(view: "list", overdue: "1")
      expect(response.body).to include("Late one")
      expect(response.body).not_to include("On time")
    end

    it "creates, updates, and deletes tasks" do
      post tasks_path, params: { task: { title: "Call new guest", priority: "high", owner_id: staff.id } }
      task = Task.find_by!(title: "Call new guest")
      expect(task).to have_attributes(created_by: staff, owner: staff)

      patch task_path(task), params: { task: { status: "done" } }
      expect(task.reload.completed_at).to be_present

      delete task_path(task)
      expect(Task.count).to eq(0)
    end

    it "moves a task on the board and answers with a Turbo Stream" do
      task = create(:task, status: "todo")
      patch move_task_path(task), params: { status: "in_progress", position: 0 }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(task.reload).to be_in_progress
    end

    it "manages and archives projects" do
      post projects_path, params: { project: { name: "Fall launch" } }
      project = Project.find_by!(name: "Fall launch")
      patch project_path(project), params: { archive: "1" }
      expect(project.reload).to be_archived
    end
  end

  context "as a task owner without manage_tasks" do
    let(:owner) { create(:user, :care_team) }
    let!(:mine) { create(:task, title: "My task", owner:) }
    let!(:theirs) { create(:task, title: "Someone else's") }

    before { sign_in_as(owner) }

    it "sees and moves only their own tasks" do
      get tasks_path
      expect(response.body).to include("My task")
      expect(response.body).not_to include("Someone else")

      patch move_task_path(mine), params: { status: "done", position: 0 }
      expect(mine.reload).to be_done

      patch move_task_path(theirs), params: { status: "done", position: 0 }
      expect(response).to have_http_status(:not_found)
    end

    it "can't reassign their task" do
      patch task_path(mine), params: { task: { title: "Renamed", owner_id: staff.id } }
      expect(mine.reload).to have_attributes(title: "Renamed", owner: owner)
    end

    it "can't create tasks" do
      post tasks_path, params: { task: { title: "Nope" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
