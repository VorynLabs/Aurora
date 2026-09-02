# Pagamento legítimo que chega quando o estoque físico já acabou: a reserva
# expirou, outra pessoa levou a última unidade, e o webhook confirma o
# pagamento anterior. O pedido é pago — o dinheiro entrou —, mas não há produto
# para entregar, e isso precisa sobreviver ao log para alguém resolver
# (reembolso ou reposição).
class AddStockConflictToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :stock_conflict, :boolean, default: false, null: false

    # Índice parcial: o que se consulta é a lista curta de pedidos a resolver,
    # nunca os milhares sem conflito.
    add_index :orders, :stock_conflict, where: "stock_conflict"
  end
end
