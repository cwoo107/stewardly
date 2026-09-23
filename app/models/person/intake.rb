# Who is this? For anything a person fills in themselves (forms, event registration):
# - A signed-in user is always their own person, and may update their details.
# - Otherwise we match an unmerged person by email. A match only has blank details
#   filled in, never overwritten, because anyone can type anyone's email.
# - With no match and a full name, a new guest is created.
#
#   intake = Person::Intake.new(user: Current.user, email: "ada@example.com", first_name: "Ada", last_name: "Lovelace")
#   intake.person                       # => matched, created, or nil
#   intake.update(person, phone: "...") # respects the fill-blanks rule
class Person::Intake
  def initialize(user: nil, email: nil, first_name: nil, last_name: nil)
    @user = user
    @email = email.to_s.strip.downcase.presence
    @first_name = first_name.to_s.strip.presence
    @last_name = last_name.to_s.strip.presence
  end

  def own? = @user.present?

  def person
    return @person if defined?(@person)

    @person = @user&.person || matched || created
  end

  # Assigns attributes (without saving) under the fill-blanks rule.
  def update(person, attributes)
    attributes.each do |attribute, value|
      next if value.blank?
      next if !own? && person[attribute].present?

      person[attribute] = value
    end
    person
  end

  private
    def matched
      @email && Person.unmerged.find_by(email: @email)
    end

    def created
      return unless @first_name && @last_name

      Person.create!(first_name: @first_name, last_name: @last_name, email: @email, membership_status: :guest)
    end
end
