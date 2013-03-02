class RenameMd5Column < ActiveRecord::Migration
  def up
    rename_column(:archives, :md5, :hash)
  end

  def down
    rename_column(:archives, :hash, :md5)
  end
end
