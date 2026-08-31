FactoryBot.define do
  factory :webhook_event do
    provider { "infinitepay" }
    sequence(:event_id) { |n| "trx_#{n}" }
    status { :received }
    payload { {} }
  end
end
