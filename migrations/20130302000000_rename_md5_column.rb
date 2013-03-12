class RenameMd5Column < ActiveRecord::Migration
  def up
    rename_column(:archives, :md5, :file_digest)
  end

  def down
    rename_column(:archives, :file_digest, :md5)
  end
end
