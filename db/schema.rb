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

ActiveRecord::Schema[8.1].define(version: 2026_07_30_201620) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "branch_payment_settings", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "money_account_id"
    t.bigint "organization_id", null: false
    t.bigint "payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "payment_method_id"], name: "index_branch_payment_settings_on_branch_and_method", unique: true
    t.index ["branch_id"], name: "index_branch_payment_settings_on_branch_id"
    t.index ["money_account_id"], name: "index_branch_payment_settings_on_money_account_id"
    t.index ["organization_id", "enabled"], name: "index_branch_payment_settings_on_organization_id_and_enabled"
    t.index ["organization_id"], name: "index_branch_payment_settings_on_organization_id"
    t.index ["payment_method_id"], name: "index_branch_payment_settings_on_payment_method_id"
  end

  create_table "branches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "main", default: false, null: false
    t.string "name", null: false
    t.bigint "next_sale_sequence", default: 1, null: false
    t.bigint "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_branches_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_branches_on_one_main_per_organization", unique: true, where: "(main = true)"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
    t.check_constraint "next_sale_sequence > 0", name: "branches_positive_sale_sequence"
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

  create_table "money_accounts", force: :cascade do |t|
    t.string "account_number"
    t.string "account_type", default: "cash", null: false
    t.boolean "active", default: true, null: false
    t.bigint "branch_id"
    t.boolean "can_pay", default: true, null: false
    t.boolean "can_receive", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.decimal "opening_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.date "opening_balance_date"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_money_accounts_on_branch_id"
    t.index ["organization_id", "account_number"], name: "index_money_accounts_on_org_and_number", unique: true, where: "(account_number IS NOT NULL)"
    t.index ["organization_id", "account_type"], name: "index_money_accounts_on_organization_id_and_account_type"
    t.index ["organization_id", "active"], name: "index_money_accounts_on_organization_id_and_active"
    t.index ["organization_id", "branch_id"], name: "index_money_accounts_on_organization_id_and_branch_id"
    t.index ["organization_id", "name"], name: "index_money_accounts_on_org_and_name", unique: true
    t.index ["organization_id"], name: "index_money_accounts_on_organization_id"
    t.check_constraint "account_type::text = ANY (ARRAY['cash'::character varying, 'petty_cash'::character varying, 'mpesa_till'::character varying, 'mpesa_paybill'::character varying, 'bank'::character varying, 'card_clearing'::character varying, 'mobile_wallet'::character varying, 'other'::character varying]::text[])", name: "money_accounts_valid_account_type"
  end

  create_table "money_transfers", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "from_money_account_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.bigint "to_money_account_id", null: false
    t.datetime "transferred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_money_account_id"], name: "index_money_transfers_on_from_money_account_id"
    t.index ["organization_id", "reference"], name: "index_money_transfers_on_organization_id_and_reference"
    t.index ["organization_id", "transferred_at"], name: "index_money_transfers_on_organization_id_and_transferred_at"
    t.index ["organization_id"], name: "index_money_transfers_on_organization_id"
    t.index ["recorded_by_id"], name: "index_money_transfers_on_recorded_by_id"
    t.index ["to_money_account_id"], name: "index_money_transfers_on_to_money_account_id"
    t.check_constraint "amount > 0::numeric", name: "money_transfers_positive_amount"
    t.check_constraint "from_money_account_id <> to_money_account_id", name: "money_transfers_different_accounts"
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

  create_table "payment_methods", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "payment_type", default: "cash", null: false
    t.boolean "requires_reference", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_payment_methods_on_organization_id_and_active"
    t.index ["organization_id", "code"], name: "index_payment_methods_on_org_and_code", unique: true
    t.index ["organization_id", "name"], name: "index_payment_methods_on_org_and_name", unique: true
    t.index ["organization_id", "payment_type"], name: "index_payment_methods_on_organization_id_and_payment_type"
    t.index ["organization_id"], name: "index_payment_methods_on_organization_id"
    t.check_constraint "payment_type::text = ANY (ARRAY['cash'::character varying, 'mobile_money'::character varying, 'bank_transfer'::character varying, 'card'::character varying, 'credit'::character varying, 'other'::character varying]::text[])", name: "payment_methods_valid_payment_type"
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

  create_table "sale_lines", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.decimal "discount_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "gross_amount", precision: 15, scale: 2, null: false
    t.bigint "item_id", null: false
    t.string "item_name", null: false
    t.string "item_type", null: false
    t.integer "line_number", null: false
    t.decimal "line_total", precision: 15, scale: 2, null: false
    t.bigint "organization_id", null: false
    t.decimal "quantity", precision: 15, scale: 4, null: false
    t.bigint "sale_id", null: false
    t.string "sku"
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "tax_rate_id"
    t.decimal "tax_rate_percentage", precision: 7, scale: 4, default: "0.0", null: false
    t.decimal "unit_cost", precision: 15, scale: 2, default: "0.0", null: false
    t.string "unit_name", null: false
    t.decimal "unit_price", precision: 15, scale: 2, null: false
    t.string "unit_symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_sale_lines_on_item_id"
    t.index ["organization_id", "item_id"], name: "index_sale_lines_on_organization_id_and_item_id"
    t.index ["organization_id", "sale_id"], name: "index_sale_lines_on_organization_id_and_sale_id"
    t.index ["organization_id"], name: "index_sale_lines_on_organization_id"
    t.index ["sale_id", "line_number"], name: "index_sale_lines_on_sale_and_line_number", unique: true
    t.index ["sale_id"], name: "index_sale_lines_on_sale_id"
    t.index ["tax_rate_id"], name: "index_sale_lines_on_tax_rate_id"
    t.check_constraint "discount_amount <= gross_amount", name: "sale_lines_discount_within_gross"
    t.check_constraint "discount_amount >= 0::numeric", name: "sale_lines_nonnegative_discount"
    t.check_constraint "gross_amount >= 0::numeric", name: "sale_lines_nonnegative_gross"
    t.check_constraint "item_type::text = ANY (ARRAY['product'::character varying, 'service'::character varying]::text[])", name: "sale_lines_allowed_item_type"
    t.check_constraint "line_number > 0", name: "sale_lines_positive_line_number"
    t.check_constraint "line_total <= gross_amount", name: "sale_lines_total_within_gross"
    t.check_constraint "line_total >= 0::numeric", name: "sale_lines_nonnegative_total"
    t.check_constraint "quantity > 0::numeric", name: "sale_lines_positive_quantity"
    t.check_constraint "tax_amount <= line_total", name: "sale_lines_tax_within_total"
    t.check_constraint "tax_amount >= 0::numeric", name: "sale_lines_nonnegative_tax"
    t.check_constraint "tax_rate_percentage <= 100::numeric", name: "sale_lines_tax_rate_within_percentage"
    t.check_constraint "tax_rate_percentage >= 0::numeric", name: "sale_lines_nonnegative_tax_rate"
    t.check_constraint "unit_cost >= 0::numeric", name: "sale_lines_nonnegative_unit_cost"
    t.check_constraint "unit_price >= 0::numeric", name: "sale_lines_nonnegative_unit_price"
  end

  create_table "sale_payments", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.decimal "amount_tendered", precision: 15, scale: 2, null: false
    t.decimal "change_given", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "money_account_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.datetime "paid_at", null: false
    t.bigint "payment_method_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.bigint "sale_id", null: false
    t.datetime "updated_at", null: false
    t.index ["money_account_id"], name: "index_sale_payments_on_money_account_id"
    t.index ["organization_id", "money_account_id"], name: "index_sale_payments_on_org_and_account"
    t.index ["organization_id", "paid_at"], name: "index_sale_payments_on_organization_id_and_paid_at"
    t.index ["organization_id", "payment_method_id"], name: "index_sale_payments_on_org_and_method"
    t.index ["organization_id", "reference"], name: "index_sale_payments_on_organization_id_and_reference"
    t.index ["organization_id"], name: "index_sale_payments_on_organization_id"
    t.index ["payment_method_id"], name: "index_sale_payments_on_payment_method_id"
    t.index ["recorded_by_id"], name: "index_sale_payments_on_recorded_by_id"
    t.index ["sale_id", "paid_at"], name: "index_sale_payments_on_sale_id_and_paid_at"
    t.index ["sale_id"], name: "index_sale_payments_on_sale_id"
    t.check_constraint "amount > 0::numeric", name: "sale_payments_positive_amount"
    t.check_constraint "amount_tendered >= amount", name: "sale_payments_tendered_covers_amount"
    t.check_constraint "change_given = (amount_tendered - amount)", name: "sale_payments_change_matches_tendered"
    t.check_constraint "change_given >= 0::numeric", name: "sale_payments_nonnegative_change"
  end

  create_table "sales", force: :cascade do |t|
    t.decimal "amount_paid", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "balance_due", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "branch_id", null: false
    t.datetime "cancelled_at"
    t.bigint "cashier_id", null: false
    t.decimal "change_given", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.decimal "discount_total", precision: 15, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "payment_status", default: "unpaid", null: false
    t.boolean "prices_include_tax", default: true, null: false
    t.string "sale_number", null: false
    t.datetime "sold_at"
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "tax_total", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "sold_at"], name: "index_sales_on_branch_and_sold_at"
    t.index ["branch_id"], name: "index_sales_on_branch_id"
    t.index ["cashier_id"], name: "index_sales_on_cashier_id"
    t.index ["customer_id", "sold_at"], name: "index_sales_on_customer_and_sold_at"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
    t.index ["organization_id", "payment_status"], name: "index_sales_on_organization_id_and_payment_status"
    t.index ["organization_id", "sale_number"], name: "index_sales_on_org_and_sale_number", unique: true
    t.index ["organization_id", "sold_at"], name: "index_sales_on_org_and_sold_at"
    t.index ["organization_id", "status"], name: "index_sales_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_sales_on_organization_id"
    t.check_constraint "(amount_paid + balance_due) = total", name: "sales_payment_balance_matches_total"
    t.check_constraint "amount_paid <= total", name: "sales_payment_within_total"
    t.check_constraint "amount_paid >= 0::numeric", name: "sales_nonnegative_amount_paid"
    t.check_constraint "balance_due >= 0::numeric", name: "sales_nonnegative_balance_due"
    t.check_constraint "change_given >= 0::numeric", name: "sales_nonnegative_change"
    t.check_constraint "discount_total <= subtotal", name: "sales_discount_within_subtotal"
    t.check_constraint "discount_total >= 0::numeric", name: "sales_nonnegative_discount"
    t.check_constraint "payment_status::text = ANY (ARRAY['unpaid'::character varying, 'partially_paid'::character varying, 'paid'::character varying]::text[])", name: "sales_allowed_payment_status"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "sales_allowed_status"
    t.check_constraint "subtotal >= 0::numeric", name: "sales_nonnegative_subtotal"
    t.check_constraint "tax_total <= total", name: "sales_tax_within_total"
    t.check_constraint "tax_total >= 0::numeric", name: "sales_nonnegative_tax"
    t.check_constraint "total >= 0::numeric", name: "sales_nonnegative_total"
  end

  create_table "stock_levels", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.datetime "last_movement_at"
    t.bigint "organization_id", null: false
    t.decimal "quantity_on_hand", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "reorder_level", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_stock_levels_on_branch_id"
    t.index ["item_id"], name: "index_stock_levels_on_item_id"
    t.index ["organization_id", "branch_id", "item_id"], name: "index_stock_levels_on_org_branch_and_item", unique: true
    t.index ["organization_id", "branch_id"], name: "index_stock_levels_on_organization_id_and_branch_id"
    t.index ["organization_id", "item_id"], name: "index_stock_levels_on_organization_id_and_item_id"
    t.index ["organization_id"], name: "index_stock_levels_on_organization_id"
    t.check_constraint "quantity_on_hand >= 0::numeric", name: "stock_levels_nonnegative_quantity"
    t.check_constraint "reorder_level >= 0::numeric", name: "stock_levels_nonnegative_reorder_level"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.string "movement_type", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.bigint "organization_id", null: false
    t.decimal "quantity_change", precision: 15, scale: 4, null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.bigint "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["branch_id", "item_id", "occurred_at"], name: "index_stock_movements_on_branch_item_and_time"
    t.index ["branch_id"], name: "index_stock_movements_on_branch_id"
    t.index ["item_id"], name: "index_stock_movements_on_item_id"
    t.index ["organization_id", "occurred_at"], name: "index_stock_movements_on_org_and_time"
    t.index ["organization_id", "reference"], name: "index_stock_movements_on_organization_id_and_reference"
    t.index ["organization_id"], name: "index_stock_movements_on_organization_id"
    t.index ["recorded_by_id"], name: "index_stock_movements_on_recorded_by_id"
    t.index ["source_type", "source_id"], name: "index_stock_movements_on_source_type_and_source_id"
    t.check_constraint "(movement_type::text = ANY (ARRAY['opening'::character varying, 'adjustment_in'::character varying, 'purchase'::character varying, 'sale_return'::character varying, 'transfer_in'::character varying]::text[])) AND quantity_change > 0::numeric OR (movement_type::text = ANY (ARRAY['adjustment_out'::character varying, 'sale'::character varying, 'purchase_return'::character varying, 'transfer_out'::character varying]::text[])) AND quantity_change < 0::numeric", name: "stock_movements_direction_matches_type"
    t.check_constraint "movement_type::text = ANY (ARRAY['opening'::character varying, 'adjustment_in'::character varying, 'adjustment_out'::character varying, 'purchase'::character varying, 'sale'::character varying, 'sale_return'::character varying, 'purchase_return'::character varying, 'transfer_in'::character varying, 'transfer_out'::character varying]::text[])", name: "stock_movements_valid_type"
    t.check_constraint "quantity_change <> 0::numeric", name: "stock_movements_nonzero_quantity"
  end

  create_table "stock_transfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_branch_id", null: false
    t.bigint "item_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.decimal "quantity", precision: 15, scale: 4, null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.bigint "to_branch_id", null: false
    t.datetime "transferred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_branch_id"], name: "index_stock_transfers_on_from_branch_id"
    t.index ["item_id"], name: "index_stock_transfers_on_item_id"
    t.index ["organization_id", "item_id"], name: "index_stock_transfers_on_organization_id_and_item_id"
    t.index ["organization_id", "reference"], name: "index_stock_transfers_on_organization_id_and_reference"
    t.index ["organization_id", "transferred_at"], name: "index_stock_transfers_on_org_and_time"
    t.index ["organization_id"], name: "index_stock_transfers_on_organization_id"
    t.index ["recorded_by_id"], name: "index_stock_transfers_on_recorded_by_id"
    t.index ["to_branch_id"], name: "index_stock_transfers_on_to_branch_id"
    t.check_constraint "from_branch_id <> to_branch_id", name: "stock_transfers_different_branches"
    t.check_constraint "quantity > 0::numeric", name: "stock_transfers_positive_quantity"
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

  add_foreign_key "branch_payment_settings", "branches"
  add_foreign_key "branch_payment_settings", "money_accounts"
  add_foreign_key "branch_payment_settings", "organizations"
  add_foreign_key "branch_payment_settings", "payment_methods"
  add_foreign_key "branches", "organizations"
  add_foreign_key "customers", "organizations"
  add_foreign_key "items", "organizations"
  add_foreign_key "items", "product_categories"
  add_foreign_key "items", "tax_rates"
  add_foreign_key "items", "unit_of_measures"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "money_accounts", "branches"
  add_foreign_key "money_accounts", "organizations"
  add_foreign_key "money_transfers", "money_accounts", column: "from_money_account_id"
  add_foreign_key "money_transfers", "money_accounts", column: "to_money_account_id"
  add_foreign_key "money_transfers", "organizations"
  add_foreign_key "money_transfers", "users", column: "recorded_by_id"
  add_foreign_key "payment_methods", "organizations"
  add_foreign_key "product_categories", "organizations"
  add_foreign_key "sale_lines", "items"
  add_foreign_key "sale_lines", "organizations"
  add_foreign_key "sale_lines", "sales"
  add_foreign_key "sale_lines", "tax_rates"
  add_foreign_key "sale_payments", "money_accounts"
  add_foreign_key "sale_payments", "organizations"
  add_foreign_key "sale_payments", "payment_methods"
  add_foreign_key "sale_payments", "sales"
  add_foreign_key "sale_payments", "users", column: "recorded_by_id"
  add_foreign_key "sales", "branches"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "organizations"
  add_foreign_key "sales", "users", column: "cashier_id"
  add_foreign_key "stock_levels", "branches"
  add_foreign_key "stock_levels", "items"
  add_foreign_key "stock_levels", "organizations"
  add_foreign_key "stock_movements", "branches"
  add_foreign_key "stock_movements", "items"
  add_foreign_key "stock_movements", "organizations"
  add_foreign_key "stock_movements", "users", column: "recorded_by_id"
  add_foreign_key "stock_transfers", "branches", column: "from_branch_id"
  add_foreign_key "stock_transfers", "branches", column: "to_branch_id"
  add_foreign_key "stock_transfers", "items"
  add_foreign_key "stock_transfers", "organizations"
  add_foreign_key "stock_transfers", "users", column: "recorded_by_id"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "tax_rates", "organizations"
  add_foreign_key "unit_of_measures", "organizations"
end
