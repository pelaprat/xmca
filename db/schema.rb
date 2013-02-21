# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110318032332) do

  create_table "assets", :force => true do |t|
    t.integer  "message_id"
    t.string   "name"
    t.string   "content_type"
    t.integer  "size"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "assets", ["message_id"], :name => "message_id"
  add_index "assets", ["name"], :name => "name"

  create_table "bodies", :force => true do |t|
    t.integer  "message_id"
    t.integer  "level"
    t.text     "original"
    t.text     "formatted"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "bodies", ["message_id"], :name => "message_id"

  create_table "emails", :force => true do |t|
    t.string   "email"
    t.integer  "person_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "emails", ["email"], :name => "email"
  add_index "emails", ["person_id"], :name => "person_id"

  create_table "messages", :force => true do |t|
    t.integer  "yarn_id"
    t.integer  "person_id"
    t.string   "subject"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "messages", ["person_id"], :name => "person_id"
  add_index "messages", ["subject"], :name => "subject"
  add_index "messages", ["yarn_id"], :name => "yarn_id"

  create_table "people", :force => true do |t|
    t.string   "first"
    t.string   "middle"
    t.string   "last"
    t.string   "password"
    t.string   "salt"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "people", ["first"], :name => "first"
  add_index "people", ["last"], :name => "last"

  create_table "yarns", :force => true do |t|
    t.string   "name"
    t.integer  "items"
    t.integer  "person_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "yarns", ["name"], :name => "name"
  add_index "yarns", ["person_id"], :name => "person_id"

end
