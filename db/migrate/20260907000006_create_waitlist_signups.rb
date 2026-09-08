class CreateWaitlistSignups < ActiveRecord::Migration[8.1]
  def change
    # Pre-launch email capture — the unique index keeps signups idempotent.
    create_table :waitlist_signups do |t|
      t.string :email_address, null: false
      t.string :source
      t.datetime :notified_at
      t.timestamps
    end
    add_index :waitlist_signups, :email_address, unique: true
  end
end
