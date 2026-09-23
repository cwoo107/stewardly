FactoryBot.define do
  factory :household do
    sequence(:name) { |n| "The Household #{n}" }
    address_line1 { "100 Main St" }
    city { "Nashville" }
    region { "TN" }
    postal_code { "37203" }

    trait :with_location do
      transient do
        latitude { 36.1627 }
        longitude { -86.7816 }
      end

      location { RGeo::Geographic.spherical_factory(srid: 4326).point(longitude, latitude) }
    end
  end
end
