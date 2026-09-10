class AddLastActiveAtToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :last_active_at, :datetime
    execute "UPDATE sessions SET last_active_at = created_at"
  end

  def down
    remove_column :sessions, :last_active_at
  end
end
