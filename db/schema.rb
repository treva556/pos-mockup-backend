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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_120612) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "branches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "main", default: false, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_branches_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_branches_on_one_main_per_organization", unique: true, where: "(main = true)"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 15, scale: 2, default: "0.0", null: false
    t.string "email"
    t.string "kra_pin"
    t.string "name", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.integer "payment_terms_days", default: 0, null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_customers_on_organization_id_and_active"
    t.index ["organization_id", "kra_pin"], name: "index_customers_on_org_and_kra_pin", unique: true, where: "(kra_pin IS NOT NULL)"
    t.index ["organization_id", "name"], name: "index_customers_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
  end

  create_table "items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "barcode"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "item_type", default: "product", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "product_category_id"
    t.decimal "purchase_cost", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "selling_price", precision: 15, scale: 2, default: "0.0", null: false
    t.string "sku"
    t.bigint "tax_rate_id"
    t.boolean "track_inventory", default: true, null: false
    t.bigint "unit_of_measure_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_items_on_organization_id_and_active"
    t.index ["organization_id", "barcode"], name: "index_items_on_org_and_barcode", unique: true, where: "(barcode IS NOT NULL)"
    t.index ["organization_id", "item_type"], name: "index_items_on_organization_id_and_item_type"
    t.index ["organization_id", "name"], name: "index_items_on_organization_id_and_name"
    t.index ["organization_id", "sku"], name: "index_items_on_org_and_sku", unique: true, where: "(sku IS NOT NULL)"
    t.index ["organization_id"], name: "index_items_on_organization_id"
    t.index ["product_category_id"], name: "index_items_on_product_category_id"
    t.index ["tax_rate_id"], name: "index_items_on_tax_rate_id"
    t.index ["unit_of_measure_id"], name: "index_items_on_unit_of_measure_id"
    t.check_constraint "item_type::text = 'product'::text OR track_inventory = false", name: "services_cannot_track_inventory"
    t.check_constraint "item_type::text = ANY (ARRAY['product'::character varying, 'service'::character varying]::text[])", name: "items_valid_item_type"
    t.check_constraint "purchase_cost >= 0::numeric", name: "items_purchase_cost_nonnegative"
    t.check_constraint "selling_price >= 0::numeric", name: "items_selling_price_nonnegative"
  end

  create_table "memberships", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "cashier", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["branch_id"], name: "index_memberships_on_branch_id"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "country_code", default: "KE", null: false
    t.datetime "created_at", null: false
    t.string "currency_code", default: "KES", null: false
    t.string "email"
    t.string "kra_pin"
    t.string "legal_name"
    t.string "name", null: false
    t.string "phone"
    t.text "receipt_footer"
    t.string "registration_number"
    t.string "time_zone", default: "Africa/Nairobi", null: false
    t.datetime "updated_at", null: false
    t.boolean "vat_registered", default: false, null: false
    t.index ["kra_pin"], name: "index_organizations_on_unique_kra_pin", unique: true, where: "(kra_pin IS NOT NULL)"
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "product_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_product_categories_on_organization_id_and_active"
    t.index ["organization_id", "name"], name: "index_product_categories_on_org_and_name", unique: true
    t.index ["organization_id"], name: "index_product_categories_on_organization_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "kra_pin"
    t.string "name", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.integer "payment_terms_days", default: 0, null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_suppliers_on_organization_id_and_active"
    t.index ["organization_id", "kra_pin"], name: "index_suppliers_on_org_and_kra_pin", unique: true, where: "(kra_pin IS NOT NULL)"
    t.index ["organization_id", "name"], name: "index_suppliers_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_suppliers_on_organization_id"
  end

  create_table "tax_rates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.decimal "rate", precision: 7, scale: 4, default: "0.0", null: false
    t.string "tax_type", default: "standard", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_tax_rates_on_organization_id_and_active"
    t.index ["organization_id", "code"], name: "index_tax_rates_on_org_and_code", unique: true
    t.index ["organization_id", "name"], name: "index_tax_rates_on_org_and_name", unique: true
    t.index ["organization_id"], name: "index_tax_rates_on_organization_id"
    t.check_constraint "rate >= 0::numeric AND rate <= 100::numeric", name: "tax_rates_rate_range"
  end

  create_table "unit_of_measures", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "decimal_allowed", default: false, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_unit_of_measures_on_organization_id_and_active"
    t.index ["organization_id", "name"], name: "index_units_on_org_and_name", unique: true
    t.index ["organization_id", "symbol"], name: "index_units_on_org_and_symbol", unique: true
    t.index ["organization_id"], name: "index_unit_of_measures_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "must_change_password", default: false, null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "platform_role", default: "regular", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "branches", "organizations"
  add_foreign_key "customers", "organizations"
  add_foreign_key "items", "organizations"
  add_foreign_key "items", "product_categories"
  add_foreign_key "items", "tax_rates"
  add_foreign_key "items", "unit_of_measures"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "product_categories", "organizations"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "tax_rates", "organizations"
  add_foreign_key "unit_of_measures", "organizations"
end
