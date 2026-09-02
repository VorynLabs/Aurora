# SKU nunca entrou em uso: nenhuma variação chegou a ter um. Enquanto a coluna
# existia, o índice único parcial sobre ela só rendia bug — o formulário mandava
# "" em vez de NULL e duas variações sem SKU colidiam.
#
# Reversível: o rollback recria coluna e índice. Os valores, não — mas não há
# nenhum para perder.
class RemoveSkuFromVariants < ActiveRecord::Migration[7.1]
  def change
    remove_index :variants, :sku, unique: true, where: "sku IS NOT NULL"
    remove_column :variants, :sku, :string
  end
end
