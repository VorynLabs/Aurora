require "rails_helper"

RSpec.describe WebhookEvent, type: :model do
  describe "idempotência" do
    it "rejeita o mesmo event_id para o mesmo provedor" do
      create(:webhook_event, provider: "infinitepay", event_id: "trx_abc")
      duplicado = build(:webhook_event, provider: "infinitepay", event_id: "trx_abc")

      expect(duplicado).not_to be_valid
      expect(duplicado.errors[:event_id]).to be_present
    end

    it "aceita o mesmo event_id em provedores diferentes" do
      create(:webhook_event, provider: "infinitepay", event_id: "trx_abc")
      outro = build(:webhook_event, provider: "outro_gateway", event_id: "trx_abc")

      expect(outro).to be_valid
    end

    it "é travado também no banco, não só na validação" do
      create(:webhook_event, provider: "infinitepay", event_id: "trx_abc")

      expect {
        described_class.new(provider: "infinitepay", event_id: "trx_abc", payload: {}).save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "status" do
    it "nasce como recebido" do
      expect(create(:webhook_event)).to be_received
    end

    it "avança para processado" do
      event = create(:webhook_event)

      event.processed!

      expect(event.reload).to be_processed
    end
  end
end
