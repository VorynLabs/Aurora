class WebhookEvent < ApplicationRecord
  enum :status, { received: 0, processed: 1, ignored: 2, failed: 3 }

  validates :event_id, uniqueness: { scope: :provider }
end
