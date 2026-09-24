require "sidekiq/web"

Rails.application.routes.draw do
  # Development's sent mail, never shown to people viewing a demo tunnel (bin/demo).
  constraints(->(request) { !DemoTunnel.tunnel_host?(request.host) }) do
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Asked by the TLS proxy before issuing a certificate (see TlsChecksController).
  get "internal/tls/allowed", to: "tls_checks#show"

  # Church websites: grace.<sites_domain> and verified custom domains. First, because a
  # sites-domain host also looks like a church subdomain. Forms and events are served
  # here too, so embedded forms submit to the site's own domain.
  constraints(SiteHost) do
    get "sitemap.xml", to: "sites/pages#sitemap", defaults: { format: :xml }
    get "robots.txt", to: "sites/pages#robots", format: false
    get "f/:slug", to: "public_forms#show", as: :site_form
    post "f/:slug", to: "public_forms#create"
    get "f/:slug/thanks", to: "public_forms#thanks", as: :site_form_thanks
    get "e/:slug", to: "public_events#show", as: :site_event
    post "e/:slug/registrations", to: "public_registrations#create", as: :site_event_registrations
    get "registrations/:token", to: "registration_managements#show", as: :site_manage_registration
    delete "registrations/:token", to: "registration_managements#destroy"
    root "sites/pages#show", as: :site_root
    # A route-level constraint replaces the block's, so SiteHost is repeated here.
    get "*path", to: "sites/pages#show", as: :site_page, format: false,
      constraints: ->(request) { !request.path.start_with?("/rails/") && SiteHost.matches?(request) }
  end

  # The admin app and platform console aren't for search engines (church websites
  # answer robots.txt themselves, above).
  get "robots.txt", to: ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "User-agent: *\nDisallow: /\n" ] ] }, format: false

  # Platform console on the bare app domain (localhost:3000 in development).
  constraints(PlatformHost) do
    # Meta: one fixed OAuth callback for every church (redirect URIs must be registered),
    # plus the deauthorize and data deletion callbacks Meta's app review requires.
    get "oauth/meta/callback", to: "meta_callbacks#oauth", as: :meta_oauth_callback
    post "oauth/meta/deauthorize", to: "meta_callbacks#deauthorize"
    post "oauth/meta/data_deletion", to: "meta_callbacks#data_deletion"
    get "oauth/meta/deletion/:code", to: "meta_callbacks#deletion_status", as: :meta_deletion_status

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
    resource :pathway, only: %i[ show edit update ]
    resources :pathway_stages, only: %i[ new create edit update destroy ] do
      patch :move, on: :member
      get :preview, on: :collection
    end

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
    resource :volunteer_load, only: %i[ show update ]

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

    # Email
    resources :email_templates, path: "email/templates" do
      member do
        get :preview
        post :test
      end
      resources :sections, controller: "email_template_sections", only: %i[ create edit update destroy ] do
        patch :move, on: :member
      end
    end
    resources :campaigns, path: "email/campaigns" do
      member do
        patch :schedule
        patch :deliver
        patch :cancel
      end
    end
    resources :email_topics, path: "email/topics", except: :show
    resources :suppressions, path: "email/suppressions", only: %i[ index create destroy ]
    resource :email_settings, path: "email/settings", only: %i[ show update ] do
      get :dns
    end
    resources :integrations, only: %i[ create update destroy ] do
      post :sync, on: :member
    end
    resources :webhook_events, path: "email/webhooks", only: %i[ index show ] do
      post :replay, on: :member
    end

    # Workflows
    resources :workflows do
      member do
        patch :publish
        patch :pause
        patch :resume
        patch :stop_runs
      end
      resource :trigger, only: %i[ edit update ], controller: "workflow_triggers"
      resources :steps, controller: "workflow_steps", only: %i[ create edit update destroy ] do
        patch :move, on: :member
      end
      resources :runs, controller: "workflow_runs", only: %i[ index show ] do
        member do
          post :retry
          patch :cancel
        end
      end
    end
    resources :message_drafts, path: "approvals", only: %i[ index edit update ] do
      patch :reject, on: :member
    end

    # Giving
    resource :giving, only: :show, controller: "giving_dashboards"
    resources :donations, path: "giving/donations", only: :index
    resources :donation_matches, path: "giving/review", only: %i[ index update ] do
      member do
        patch :ignore
        post :create_person
      end
    end
    resources :funds, path: "giving/funds", only: %i[ index new create edit update ]
    resource :giving_settings, path: "giving/settings", only: :show do
      post :sync
    end

    # Benevolence
    resources :benevolence_cases, path: "benevolence", only: %i[ index show new create edit update ] do
      get :report, on: :collection
      member do
        post :decide
      end
      resources :notes, controller: "benevolence_notes", only: :create
      resources :disbursements, controller: "benevolence_disbursements", only: :create
    end

    # Insights and reports
    resources :insights, only: :index do
      member do
        patch :resolve
        patch :dismiss
        patch :snooze
        post :assign
      end
    end
    resource :daily_brief, only: %i[ create update ]
    resources :report_conversations, path: "reports/ask", only: %i[ index show create ] do
      resources :messages, controller: "report_messages", only: %i[ create show ]
    end
    resources :saved_reports, path: "reports/saved", only: %i[ index show create update destroy ] do
      post :rerun, on: :member
    end
    resources :metrics, path: "reports/metrics", only: %i[ index show ], param: :name

    # Website
    resource :website, only: %i[ show update ]
    namespace :website do
      resource :theme, only: %i[ edit update ]
      resource :layout, only: %i[ edit update destroy ]
      resources :pages, except: :index do
        member do
          get :preview
          patch :publish
          patch :unpublish
          patch :discard
          patch :move
        end
        resources :sections, controller: "page_sections", only: %i[ create edit update destroy ] do
          patch :move, on: :member
        end
        resources :revisions, controller: "page_revisions", only: :index do
          post :restore, on: :member
        end
      end
      resources :sections, except: %i[ show destroy ] do
        post :reset, on: :member
      end
      resources :domains, only: %i[ create destroy ] do
        member do
          post :check
          patch :primary
        end
      end
    end

    # Social media
    resources :social_posts, path: "social/posts" do
      member do
        patch :schedule
        patch :publish_now
        patch :cancel
        post :polish
      end
      resources :targets, controller: "social_post_targets", only: [] do
        member do
          post :retry
          patch :mark_posted
        end
      end
    end
    resource :social_calendar, path: "social/calendar", only: :show
    resources :social_accounts, path: "social/accounts", only: %i[ index destroy ] do
      get :connect, on: :collection
      post :check, on: :member
    end

    # Public email endpoints (no sign-in)
    post "webhooks/:token", to: "webhooks#create", as: :webhook
    get "u/:token", to: "unsubscribes#show", as: :unsubscribe
    post "u/:token", to: "unsubscribes#create"
    get "email_preferences/:token", to: "email_preferences#show", as: :email_preferences
    patch "email_preferences/:token", to: "email_preferences#update"
    get "t/o/:token", to: "email_tracking#open", as: :email_open # /t/o/TOKEN.gif
    get "t/c/:token/:signed", to: "email_tracking#click", as: :email_click, constraints: { signed: /[^\/]+/ }

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
