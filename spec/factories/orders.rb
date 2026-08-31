FactoryBot.define do
  factory :order do
    status { :pending }
    total_cents { 4_990 }
    reserved_until { 30.minutes.from_now }
  end
end
