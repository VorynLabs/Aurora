class ApplicationController < ActionController::Base
  helper_method :current_cart

  private

  def current_cart = @current_cart ||= Cart.new(session)
end
