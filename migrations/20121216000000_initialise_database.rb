class InitialiseDatabase < ActiveRecord::Migration
  def up
    create_table :archives do |t|
      t.string    :filename
      t.string    :md5
      t.timestamp :archived_at
    end

    add_index :archives, :filename
  end

  def version; 1; end
end
