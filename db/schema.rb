# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_10_002056) do
  create_table "answers", force: :cascade do |t|
    t.integer "number_value"
    t.string "option_id"
    t.integer "position"
    t.string "question_id", null: false
    t.integer "response_id", null: false
    t.text "text_value"
    t.index ["response_id", "question_id"], name: "index_answers_on_response_id_and_question_id"
    t.index ["response_id"], name: "index_answers_on_response_id"
  end

  create_table "magic_links", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["token"], name: "index_magic_links_on_token", unique: true
    t.index ["user_id"], name: "index_magic_links_on_user_id"
  end

  create_table "responses", force: :cascade do |t|
    t.integer "completion", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "edition_id", null: false
    t.string "locale"
    t.string "source"
    t.datetime "started_at", null: false
    t.datetime "submitted_at"
    t.integer "survey_version", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["edition_id", "user_id"], name: "index_responses_on_edition_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_responses_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "waitlist_signups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "notified_at"
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_waitlist_signups_on_email_address", unique: true
  end

  add_foreign_key "answers", "responses", on_delete: :cascade
  add_foreign_key "magic_links", "users"
  add_foreign_key "responses", "users"
  add_foreign_key "sessions", "users"
end
