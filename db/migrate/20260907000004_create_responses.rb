class CreateResponses < ActiveRecord::Migration[8.1]
  def change
    # One row per user per edition — the unique index IS the one-vote rule.
    create_table :responses do |t|
      t.string :edition_id, null: false
      t.integer :survey_version, null: false
      t.references :user, null: false, foreign_key: true
      t.string :source
      t.datetime :started_at, null: false
      t.datetime :submitted_at
      t.integer :completion, null: false, default: 0
      t.string :user_agent
      t.string :locale
      t.timestamps
    end
    add_index :responses, [ :edition_id, :user_id ], unique: true
  end
end
