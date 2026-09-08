class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false   # short code typed on the sign-in page
      t.string :token, null: false  # long token embedded in the emailed link
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :magic_links, :code, unique: true
    add_index :magic_links, :token, unique: true
    add_index :magic_links, :expires_at
  end
end
