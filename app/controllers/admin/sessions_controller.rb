class Admin::SessionsController < Devise::SessionsController
  layout "admin"

  private

  # Volta para onde o admin tentou ir antes de ser barrado; na falta disso, o painel.
  def after_sign_in_path_for(resource) = stored_location_for(resource) || admin_root_path

  # Não há catálogo ainda (escopo posterior), então o destino do logout é o login.
  def after_sign_out_path_for(_resource_or_scope) = new_admin_session_path
end
