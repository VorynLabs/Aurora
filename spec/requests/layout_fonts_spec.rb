require "rails_helper"

# As fontes do SPEC 05 chegam por um <link> só, e um <link> some fácil numa
# mexida de layout. Sem elas o app cai na serifada e na sans do sistema, que é
# justamente o que a identidade não quer.
RSpec.describe "Fontes do layout", type: :request do
  shared_examples "carrega as fontes do SPEC 05" do
    it "pede Playfair Display e Inter ao Google Fonts, com swap" do
      expect(response.body).to include("https://fonts.googleapis.com/css2")
      expect(response.body).to include("family=Inter:wght@400;500")
      expect(response.body).to include("family=Playfair+Display:wght@500")
      expect(response.body).to include("display=swap")
      expect(response.body).to include('rel="preconnect" href="https://fonts.gstatic.com"')
    end
  end

  describe "catálogo" do
    before { get root_path }

    include_examples "carrega as fontes do SPEC 05"
  end

  describe "painel" do
    before do
      sign_in create(:admin)
      get admin_root_path
    end

    include_examples "carrega as fontes do SPEC 05"
  end
end
