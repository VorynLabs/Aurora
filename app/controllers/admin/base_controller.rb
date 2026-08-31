# Base de todo o painel: nada em /admin é acessível sem login.
#
# Forma compacta (`class Admin::BaseController`) de propósito: `Admin` é uma
# classe (o model), então `module Admin` levantaria TypeError.
class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!

  layout "admin"
end
