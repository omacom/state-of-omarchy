class CreateAnswers < ActiveRecord::Migration[8.1]
  def change
    # Normalized answers, one row per selected option / list item / value:
    # - single: one row with option_id (+ text_value for the "other" write-in)
    # - multiple: one row per selected option_id
    # - scale/nps: number_value
    # - text: text_value; text_list: one row per item (text_value + position)
    # - country: option_id = iso2 (or the skip option id)
    create_table :answers do |t|
      t.references :response, null: false, foreign_key: { on_delete: :cascade }
      t.string :question_id, null: false
      t.string :option_id
      t.integer :number_value
      t.text :text_value
      t.integer :position
    end
    add_index :answers, [ :response_id, :question_id ]
  end
end
