require "sidekiq/web"

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Platform console on the bare app domain (localhost:3000 in development).
  constraints(PlatformHost) do
    scope module: :platform, as: :platform do
      resource :session, only: %i[ new create destroy ]
      resources :churches, only: %i[ index new create ]
      root "churches#index"
    end

    constraints(PlatformAdminSignedIn) do
      mount Sidekiq::Web => "/sidekiq"
    end
  end

  # Church admin app and member area on church subdomains (grace.localhost:3000).
  constraints(ChurchSubdomain) do
    resource :session, only: %i[ new create destroy ]
    resources :passwords, param: :token, only: %i[ new create edit update ]

    resource :church_settings, only: %i[ edit update ]
    resources :users, only: %i[ index show destroy ] do
      resources :user_roles, only: %i[ create destroy ]
    end
    resources :roles, only: %i[ index show ]
    resources :audit_events, only: :index

    # People
    resources :people do
      get :search, on: :collection
      resource :account_invitation, only: :create
      resources :touchpoints, only: :create
      resource :merge, only: %i[ new create ], controller: "person_merges"
    end
    resources :households
    resources :person_imports, path: "imports", only: %i[ index new create show edit update ]
    resources :duplicates, only: :index
    resources :duplicate_dismissals, only: :create
    resources :segments do
      collection do
        get :preview
        get :condition
      end
    end
    resource :map, only: :show

    # Settings for people
    resources :tags, except: :show
    resources :custom_fields, except: :show do
      patch :move, on: :member
    end
    resources :campuses, except: :show

    # Organization
    resources :ministries do
      resources :ministry_leaderships, only: %i[ create destroy ]
    end
    resources :groups do
      resources :group_memberships, only: %i[ create update destroy ]
      resources :join_requests, only: :update, controller: "group_join_requests"
    end
    resources :teams, except: :index do
      resources :positions, only: %i[ create destroy ]
      resources :team_memberships, only: %i[ create update destroy ]
      resources :position_qualifications, only: %i[ create destroy ]
      resource :schedule, only: :show, controller: "team_schedules" do
        post :auto_fill
        post :send_requests
      end
    end

    # Scheduling
    resources :worship_services, except: :show

    # Attendance
    resource :attendance, only: :show, controller: "attendance_dashboards"
    get "attendance/counts", to: "attendance_counts#edit", as: :attendance_counts
    patch "attendance/counts", to: "attendance_counts#update"
    get "attendance/accuracy", to: "attendance_forecasts#index", as: :attendance_accuracy
    resources :special_sundays, except: :show
    resources :service_occurrences, only: [] do
      resource :check_in, only: :show, controller: "service_check_ins"
      resources :attendances, only: %i[ create destroy ]
    end
    resources :position_needs, only: %i[ create update destroy ]
    resources :assignments, only: %i[ create update destroy ] do
      get :suggestions, on: :collection
    end

    # Events and courses
    resources :events do
      member do
        patch :publish
        patch :cancel
      end
      resources :occurrences, controller: "event_occurrences", only: %i[ create update destroy ] do
        resource :check_in, only: :show, controller: "event_check_ins"
      end
      resources :registrations, only: %i[ index create update ]
    end
    resources :courses
    resources :course_offerings, except: :index do
      resources :sessions, controller: "course_sessions", only: %i[ create destroy ]
      resources :enrollments, only: %i[ create update ]
      resource :attendance, only: :update, controller: "session_attendances"
    end
    resource :calendar, only: :show
    resources :announcements, except: :show

    # Forms
    resources :forms do
      member do
        patch :publish
        patch :close
        get :preview
      end
      resources :fields, controller: "form_fields", only: %i[ create show edit update destroy ] do
        patch :move, on: :member
      end
      resources :submissions, controller: "form_submissions", only: %i[ index show update ]
    end

    # Public forms (no sign-in)
    get "f/:slug", to: "public_forms#show", as: :public_form
    post "f/:slug", to: "public_forms#create"
    get "f/:slug/thanks", to: "public_forms#thanks", as: :public_form_thanks
    get "e/:slug", to: "public_events#show", as: :public_event
    post "e/:slug/registrations", to: "public_registrations#create", as: :public_event_registrations
    get "registrations/:token", to: "registration_managements#show", as: :manage_registration
    delete "registrations/:token", to: "registration_managements#destroy"
    get "respond/:token", to: "assignment_responses#show", as: :assignment_response
    patch "respond/:token", to: "assignment_responses#update"
    resource :account_setup, only: %i[ new create edit update ]

    # Member area
    namespace :member, path: "me" do
      root "homes#show"
      resources :assignments, only: %i[ index update ]
      resources :blockouts, only: %i[ create destroy ]
      resource :calendar, only: :show
      resources :events, only: %i[ index show ] do
        resources :registrations, only: :create
      end
      resources :registrations, only: :destroy
      resources :courses, only: :index
      resources :enrollments, only: %i[ create destroy ]
      resources :groups, only: %i[ index show ] do
        resources :join_requests, only: :create
      end
      resource :profile, only: %i[ show edit update ]
      resources :household_members, only: %i[ new create edit update ]
      resources :prayers, only: :index
    end

    # Work
    resources :projects, except: :show
    resources :tasks do
      patch :move, on: :member
    end
    resources :prayer_requests do
      resources :prayer_assignments, only: %i[ create destroy ]
      resources :follow_ups, only: :create, controller: "prayer_follow_ups"
    end

    root "dashboards#show"
  end
end
