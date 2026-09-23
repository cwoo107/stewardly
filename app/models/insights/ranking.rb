# Orders a user's open insights without AI: severity first, then whether it's theirs
# directly, then how long it has waited. This is also where the AI brief starts from.
class Insights::Ranking
  def initialize(user, church: user.church)
    @user = user
    @church = church
  end

  def insights(limit: nil)
    ranked = Insight.open.visible_to(@user).includes(:subject).to_a.sort_by { |insight| -score(insight) }
    limit ? ranked.first(limit) : ranked
  end

  def score(insight)
    Insight::SEVERITY_WEIGHTS.fetch(insight.severity) * 10 + (insight.mine?(@user) ? 6 : 0) + [ insight.age_days, 14 ].min / 2.0
  end
end
