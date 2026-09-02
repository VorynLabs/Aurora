require "rails_helper"

# Job de fallback que não está agendado é job que não existe: o estoque
# continuaria preso e o pedido pago continuaria pendente.
RSpec.describe "Agendamento recorrente" do
  let(:schedule) { YAML.load_file(Rails.root.join("config/recurring.yml")) }

  %w[development production].each do |env|
    describe env do
      let(:tasks) { schedule.fetch(env) }

      it "expira reservas a cada 2 minutos" do
        expect(tasks["expire_reservations"])
          .to include("class" => "ExpireReservationsJob", "schedule" => "every 2 minutes")
      end

      it "concilia pagamentos pendentes a cada 10 minutos" do
        expect(tasks["reconcile_pending_payments"])
          .to include("class" => "ReconcilePendingPaymentsJob", "schedule" => "every 10 minutes")
      end
    end
  end

  it "agenda só classes de job que existem" do
    classes = schedule.values.flat_map { |tasks| tasks.values.filter_map { _1["class"] } }.uniq

    expect(classes).to all(satisfy { |name| name.safe_constantize.present? })
  end
end
