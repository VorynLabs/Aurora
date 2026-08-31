# Carrinho na sessão: não há cadastro de cliente na v1. Guarda só pares
# variant_id => quantidade; as variações são resolvidas no banco na hora de
# mostrar, então preço e estoque nunca ficam congelados dentro do cookie.
#
# Não é ActiveRecord.
class Cart
  def initialize(store)
    @items = (store[:cart] ||= {})
  end

  # Carrinho de uma compra só, fora da sessão: é o "Comprar agora" do detalhe.
  def self.ephemeral(variant_id, quantity)
    new({}).tap { |cart| cart.add(variant_id, quantity) }
  end

  def add(variant_id, quantity)
    quantity = quantity.to_i
    return if quantity <= 0

    key = variant_id.to_s
    @items[key] = @items[key].to_i + quantity
  end

  def set(variant_id, quantity)
    quantity = quantity.to_i
    return remove(variant_id) if quantity <= 0

    @items[variant_id.to_s] = quantity
  end

  def remove(variant_id) = @items.delete(variant_id.to_s)

  # Mantém a ordem em que os itens entraram. Variação que sumiu da base
  # simplesmente não aparece.
  def line_items
    variants = Variant.where(id: @items.keys)
                      .includes(:product)
                      .index_by { |variant| variant.id.to_s }

    @items.filter_map do |variant_id, quantity|
      next unless (variant = variants[variant_id])

      { variant: variant, quantity: quantity.to_i }
    end
  end

  def total_cents = line_items.sum { |line| line[:variant].price_cents * line[:quantity] }

  def count = @items.values.sum(&:to_i)

  def empty? = @items.empty?
end
