class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :variants, through: :order_items

  # Quanto tempo o checkout segura as unidades. Mora aqui, e não no serviço que
  # reserva, porque a conciliação também precisa saber quando a janela acaba.
  RESERVATION_WINDOW = 7.minutes

  # Até quando ainda vale procurar um pagamento cujo webhook se perdeu. Depois
  # disso o caso é velho demais para um job resolver sozinho.
  RECONCILIATION_WINDOW = 2.hours

  enum :status, { pending: 0, paid: 1, expired: 2, canceled: 3 }

  validates :order_nsu, presence: true, uniqueness: true

  before_validation :generate_order_nsu, on: :create

  scope :stale_pending, -> { pending.where("reserved_until < ?", Time.current) }

  # O que a conciliação deve consultar na InfinitePay.
  #
  # Duas condições, uma por status:
  #   pendente — só depois que a reserva acabou. Antes disso o cliente ainda
  #   está pagando e o estoque segue reservado: não há nada a resgatar, e
  #   consultar seria gastar chamada para ouvir "não pago".
  #   expirado — o ExpireReservationsJob marca assim entre 7 e 9 minutos, e é
  #   exatamente aí que mora o pagamento cujo webhook se perdeu. Sem incluir
  #   estes, o fallback falharia no caso que existe para cobrir.
  #
  # `reserved_until <= agora` é o fim da janela de reserva, e o limite de baixo
  # descarta o que já é velho demais.
  scope :awaiting_reconciliation, -> {
    where(status: [statuses[:pending], statuses[:expired]])
      .where(reserved_until: RECONCILIATION_WINDOW.ago..Time.current)
  }

  # Pagos sem estoque físico para entregar. Precisam de decisão humana:
  # reembolsar ou repor. Ver Payments::SettlePaidOrder.
  scope :needs_review, -> { where(stock_conflict: true) }

  private

  def generate_order_nsu = self.order_nsu ||= "ord_#{SecureRandom.hex(12)}"
end
