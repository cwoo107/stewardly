# Sets up a new church: the church itself, its default roles, a default campus,
# starter forms, and a first church admin (with the Person that user belongs to),
# in one transaction.
class Church::Provisioning
  attr_reader :church, :admin

  def initialize(name:, subdomain:, time_zone:, admin:)
    @church = Church.new(name:, subdomain:, time_zone:)
    @admin_attributes = admin
  end

  def provision!
    Church.transaction do
      church.save!
      ActsAsTenant.with_tenant(church) do
        roles = Role::DEFAULTS.map { |attributes| Role.create!(attributes.merge(system: true)) }
        Campus.create!(name: "Main campus", is_default: true)
        Form::Starters.install!
        @admin = create_admin(roles.find(&:church_admin?))
      end
    end
    church
  end

  private
    def create_admin(admin_role)
      attributes = @admin_attributes.to_h.symbolize_keys
      person = Person.create!(first_name: attributes.fetch(:first_name), last_name: attributes.fetch(:last_name),
        email: attributes.fetch(:email_address), membership_status: :member)
      User.create!(person:, email_address: attributes.fetch(:email_address), password: attributes.fetch(:password),
        roles: [ admin_role ])
    end
end
