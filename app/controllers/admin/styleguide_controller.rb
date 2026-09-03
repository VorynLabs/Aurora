# Página interna que mostra todos os componentes e cores juntos. Serve para
# revisar a identidade antes de aplicá-la nas telas de negócio.
class Admin::StyleguideController < Admin::BaseController
  PALETTE = [
    { token: "wine",      hex: "#5B1A2E", usage: "Cabeçalho, botão primário, preço em destaque" },
    { token: "wine-dark", hex: "#3A0E1C", usage: "Hover do primário, texto sobre nude" },
    { token: "wine-ink",  hex: "#2B1218", usage: "Texto forte, cabeçalho do painel" },
    { token: "nude",      hex: "#F3E1D8", usage: "Fundo de seções" },
    { token: "nude-deep", hex: "#E4C4B4", usage: "Bordas e placeholder de imagem" },
    { token: "cream",     hex: "#FBF3EE", usage: "Fundo de página" },
    { token: "clay",      hex: "#C97B5A", usage: "Realce e focus ring — nunca texto" },
    { token: "clay-text", hex: "#8A5240", usage: "Texto secundário" },
    { token: "success",   hex: "#3B6D57", usage: "Em estoque, confirmações" },
    { token: "warning",   hex: "#B07A2E", usage: "Últimas unidades" },
    { token: "danger",    hex: "#8A2D2D", usage: "Erros, esgotado" },
    { token: "warning-text", hex: "#85581A", usage: "Âmbar como texto — o cheio reprova o AA" }
  ].freeze

  def index
    @palette = PALETTE

    # Mensagens de verdade, para o componente ser visto como ele é em uso.
    flash.now[:notice] = "Produto atualizado."
    flash.now[:alert] = "Esse item está sem estoque. Veja similares."
  end
end
