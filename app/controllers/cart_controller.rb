class CartController < ApplicationController
  layout "catalog"

  def show
    @cart = current_cart
  end

  # O :id das rotas de linha é o id da variação — é ele que identifica o item.
  def add
    current_cart.add(params[:variant_id], params[:quantity])
    respond_to_cart_change
  end

  def update
    current_cart.set(params[:id], params[:quantity])
    respond_to_cart_change
  end

  def remove
    current_cart.remove(params[:id])
    respond_to_cart_change
  end

  private

  # As três mudanças redesenham as mesmas partes: o carrinho do cabeçalho e,
  # quando o cliente está nela, a página do carrinho.
  def respond_to_cart_change
    respond_to do |format|
      format.turbo_stream { render :change }
      format.html { redirect_to cart_path }
    end
  end
end
