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

ActiveRecord::Schema[8.1].define(version: 2026_08_12_184547) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounting_account_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ledger_account_id", null: false
    t.bigint "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_account_id"], name: "index_accounting_account_mappings_on_ledger_account_id"
    t.index ["organization_id", "role"], name: "index_accounting_mappings_on_org_and_role", unique: true
    t.index ["organization_id"], name: "index_accounting_account_mappings_on_organization_id"
    t.check_constraint "role::text = ANY (ARRAY['accounts_receivable'::character varying, 'inventory'::character varying, 'supplier_credit_receivable'::character varying, 'accounts_payable'::character varying, 'customer_refund_payable'::character varying, 'sales_revenue'::character varying, 'sales_returns'::character varying, 'cost_of_goods_sold'::character varying, 'input_tax'::character varying, 'output_tax'::character varying, 'retained_earnings'::character varying, 'opening_balance_equity'::character varying, 'inventory_adjustment_gain'::character varying, 'inventory_adjustment_loss'::character varying]::text[])", name: "accounting_account_mappings_role_check"
  end

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
    t.integer "next_purchase_return_sequence", default: 1, null: false
    t.bigint "next_purchase_sequence", default: 1, null: false
    t.integer "next_sale_return_sequence", default: 1, null: false
    t.bigint "next_sale_sequence", default: 1, null: false
    t.bigint "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_branches_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_branches_on_one_main_per_organization", unique: true, where: "(main = true)"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
    t.check_constraint "next_purchase_return_sequence > 0", name: "branches_purchase_return_sequence_positive"
    t.check_constraint "next_purchase_sequence > 0", name: "branches_next_purchase_sequence_positive"
    t.check_constraint "next_sale_return_sequence > 0", name: "branches_sale_return_sequence_positive"
    t.check_constraint "next_sale_sequence > 0", name: "branches_positive_sale_sequence"
  end

  create_table "customer_refunds", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "money_account_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "payment_method_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.datetime "refunded_at", null: false
    t.bigint "sale_return_id", null: false
    t.datetime "updated_at", null: false
    t.index ["money_account_id"], name: "index_customer_refunds_on_money_account_id"
    t.index ["organization_id", "money_account_id"], name: "index_customer_refunds_on_org_and_account"
    t.index ["organization_id", "refunded_at"], name: "index_customer_refunds_on_org_and_time"
    t.index ["organization_id"], name: "index_customer_refunds_on_organization_id"
    t.index ["payment_method_id"], name: "index_customer_refunds_on_payment_method_id"
    t.index ["recorded_by_id"], name: "index_customer_refunds_on_recorded_by_id"
    t.index ["sale_return_id", "refunded_at"], name: "index_customer_refunds_on_return_and_time"
    t.index ["sale_return_id"], name: "index_customer_refunds_on_sale_return_id"
    t.check_constraint "amount > 0::numeric", name: "customer_refunds_amount_positive"
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

  create_table "inventory_batches", force: :cascade do |t|
    t.string "batch_number"
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.date "expires_on", null: false
    t.bigint "item_id", null: false
    t.date "manufactured_on"
    t.bigint "organization_id", null: false
    t.bigint "purchase_line_id"
    t.decimal "quantity_received", precision: 15, scale: 4, null: false
    t.decimal "quantity_remaining", precision: 15, scale: 4, null: false
    t.datetime "received_at", null: false
    t.string "status", default: "active", null: false
    t.decimal "unit_cost", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_inventory_batches_on_branch_id"
    t.index ["item_id"], name: "index_inventory_batches_on_item_id"
    t.index ["organization_id", "branch_id", "item_id", "batch_number"], name: "index_unique_inventory_batch_number", unique: true, where: "((batch_number IS NOT NULL) AND ((batch_number)::text <> ''::text))"
    t.index ["organization_id", "branch_id", "item_id", "expires_on"], name: "index_batches_for_expiry_lookup"
    t.index ["organization_id", "status", "expires_on"], name: "index_batches_for_expiry_reports"
    t.index ["organization_id"], name: "index_inventory_batches_on_organization_id"
    t.index ["purchase_line_id"], name: "index_inventory_batches_on_purchase_line_id"
    t.check_constraint "manufactured_on IS NULL OR manufactured_on <= expires_on", name: "inventory_batches_manufacture_before_expiry"
    t.check_constraint "quantity_received > 0::numeric", name: "inventory_batches_received_quantity_positive"
    t.check_constraint "quantity_remaining <= quantity_received", name: "inventory_batches_remaining_not_above_received"
    t.check_constraint "quantity_remaining >= 0::numeric", name: "inventory_batches_remaining_quantity_nonnegative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'quarantined'::character varying, 'depleted'::character varying]::text[])", name: "inventory_batches_status_valid"
    t.check_constraint "unit_cost >= 0::numeric", name: "inventory_batches_unit_cost_nonnegative"
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
    t.boolean "tracks_expiry", default: false, null: false
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

  create_table "ledger_accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "normal_balance", null: false
    t.bigint "organization_id", null: false
    t.bigint "parent_id"
    t.boolean "postable", default: true, null: false
    t.string "report_group", null: false
    t.boolean "system_account", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "account_type"], name: "index_ledger_accounts_on_org_and_type"
    t.index ["organization_id", "code"], name: "index_ledger_accounts_on_org_and_code", unique: true
    t.index ["organization_id"], name: "index_ledger_accounts_on_organization_id"
    t.index ["parent_id"], name: "index_ledger_accounts_on_parent_id"
    t.check_constraint "account_type::text = ANY (ARRAY['asset'::character varying, 'liability'::character varying, 'equity'::character varying, 'revenue'::character varying, 'expense'::character varying]::text[])", name: "ledger_accounts_account_type_check"
    t.check_constraint "normal_balance::text = ANY (ARRAY['debit'::character varying, 'credit'::character varying]::text[])", name: "ledger_accounts_normal_balance_check"
    t.check_constraint "report_group::text = ANY (ARRAY['current_asset'::character varying, 'non_current_asset'::character varying, 'contra_asset'::character varying, 'current_liability'::character varying, 'non_current_liability'::character varying, 'equity'::character varying, 'revenue'::character varying, 'contra_revenue'::character varying, 'cost_of_sales'::character varying, 'operating_expense'::character varying, 'other_income'::character varying, 'other_expense'::character varying]::text[])", name: "ledger_accounts_report_group_check"
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
    t.bigint "ledger_account_id"
    t.string "name", null: false
    t.text "notes"
    t.decimal "opening_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.date "opening_balance_date"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_money_accounts_on_branch_id"
    t.index ["ledger_account_id"], name: "index_money_accounts_on_ledger_account_id"
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

  create_table "purchase_lines", force: :cascade do |t|
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
    t.bigint "purchase_id", null: false
    t.decimal "quantity", precision: 15, scale: 4, null: false
    t.string "sku"
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "tax_percentage", precision: 7, scale: 4, default: "0.0", null: false
    t.bigint "tax_rate_id"
    t.decimal "unit_cost", precision: 15, scale: 2, null: false
    t.string "unit_name", null: false
    t.string "unit_symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_purchase_lines_on_item_id"
    t.index ["organization_id"], name: "index_purchase_lines_on_organization_id"
    t.index ["purchase_id", "line_number"], name: "index_purchase_lines_on_purchase_id_and_line_number", unique: true
    t.index ["purchase_id"], name: "index_purchase_lines_on_purchase_id"
    t.index ["tax_rate_id"], name: "index_purchase_lines_on_tax_rate_id"
    t.check_constraint "line_number > 0", name: "purchase_lines_line_number_positive"
    t.check_constraint "quantity > 0::numeric", name: "purchase_lines_quantity_positive"
    t.check_constraint "unit_cost >= 0::numeric AND gross_amount >= 0::numeric AND discount_amount >= 0::numeric AND tax_percentage >= 0::numeric AND tax_amount >= 0::numeric AND line_total >= 0::numeric", name: "purchase_lines_amounts_nonnegative"
  end

  create_table "purchase_payments", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "money_account_id", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.datetime "paid_at", null: false
    t.bigint "payment_method_id", null: false
    t.bigint "purchase_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["money_account_id"], name: "index_purchase_payments_on_money_account_id"
    t.index ["organization_id", "paid_at"], name: "index_purchase_payments_on_organization_id_and_paid_at"
    t.index ["organization_id"], name: "index_purchase_payments_on_organization_id"
    t.index ["payment_method_id"], name: "index_purchase_payments_on_payment_method_id"
    t.index ["purchase_id"], name: "index_purchase_payments_on_purchase_id"
    t.index ["recorded_by_id"], name: "index_purchase_payments_on_recorded_by_id"
    t.check_constraint "amount > 0::numeric", name: "purchase_payments_amount_positive"
  end

  create_table "purchase_return_lines", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.decimal "discount_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "gross_amount", precision: 15, scale: 2, null: false
    t.bigint "inventory_batch_id"
    t.bigint "item_id", null: false
    t.string "item_name", null: false
    t.string "item_type", null: false
    t.integer "line_number", null: false
    t.decimal "line_total", precision: 15, scale: 2, null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_line_id", null: false
    t.bigint "purchase_return_id", null: false
    t.decimal "quantity", precision: 15, scale: 4, null: false
    t.string "reason_code"
    t.string "sku"
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "tax_percentage", precision: 7, scale: 4, default: "0.0", null: false
    t.decimal "unit_cost", precision: 15, scale: 2, null: false
    t.string "unit_name", null: false
    t.string "unit_symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_batch_id"], name: "index_purchase_return_lines_on_inventory_batch_id"
    t.index ["item_id"], name: "index_purchase_return_lines_on_item_id"
    t.index ["organization_id", "item_id"], name: "index_purchase_return_lines_on_org_and_item"
    t.index ["organization_id"], name: "index_purchase_return_lines_on_organization_id"
    t.index ["purchase_line_id", "inventory_batch_id"], name: "index_purchase_return_lines_on_source_and_batch"
    t.index ["purchase_line_id"], name: "index_purchase_return_lines_on_purchase_line_id"
    t.index ["purchase_return_id", "line_number"], name: "index_purchase_return_lines_on_return_and_line", unique: true
    t.index ["purchase_return_id"], name: "index_purchase_return_lines_on_purchase_return_id"
    t.check_constraint "discount_amount <= gross_amount", name: "purchase_return_lines_discount_within_gross"
    t.check_constraint "item_type::text = ANY (ARRAY['product'::character varying, 'service'::character varying]::text[])", name: "purchase_return_lines_item_type_valid"
    t.check_constraint "line_number > 0", name: "purchase_return_lines_line_number_positive"
    t.check_constraint "line_total <= gross_amount", name: "purchase_return_lines_total_within_gross"
    t.check_constraint "quantity > 0::numeric", name: "purchase_return_lines_quantity_positive"
    t.check_constraint "tax_amount <= line_total", name: "purchase_return_lines_tax_within_total"
    t.check_constraint "unit_cost >= 0::numeric AND gross_amount >= 0::numeric AND discount_amount >= 0::numeric AND tax_percentage >= 0::numeric AND tax_amount >= 0::numeric AND line_total >= 0::numeric", name: "purchase_return_lines_amounts_nonnegative"
  end

  create_table "purchase_returns", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.decimal "discount_total", precision: 15, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_id", null: false
    t.string "reason_code", default: "other", null: false
    t.text "reason_details"
    t.bigint "recorded_by_id", null: false
    t.string "return_number", null: false
    t.datetime "returned_at"
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 15, scale: 2, default: "0.0", null: false
    t.string "supplier_document_number"
    t.decimal "tax_total", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "returned_at"], name: "index_purchase_returns_on_branch_and_time"
    t.index ["branch_id"], name: "index_purchase_returns_on_branch_id"
    t.index ["organization_id", "return_number"], name: "index_purchase_returns_on_org_and_number", unique: true
    t.index ["organization_id", "status"], name: "index_purchase_returns_on_org_and_status"
    t.index ["organization_id"], name: "index_purchase_returns_on_organization_id"
    t.index ["purchase_id", "returned_at"], name: "index_purchase_returns_on_purchase_and_time"
    t.index ["purchase_id"], name: "index_purchase_returns_on_purchase_id"
    t.index ["recorded_by_id"], name: "index_purchase_returns_on_recorded_by_id"
    t.check_constraint "discount_total <= subtotal", name: "purchase_returns_discount_within_subtotal"
    t.check_constraint "status::text <> 'completed'::text OR returned_at IS NOT NULL", name: "purchase_returns_completed_has_time"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "purchase_returns_status_valid"
    t.check_constraint "subtotal >= 0::numeric AND discount_total >= 0::numeric AND tax_total >= 0::numeric AND total >= 0::numeric", name: "purchase_returns_amounts_nonnegative"
    t.check_constraint "tax_total <= total", name: "purchase_returns_tax_within_total"
  end

  create_table "purchases", force: :cascade do |t|
    t.decimal "amount_paid", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "balance_due", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.decimal "discount_total", precision: 15, scale: 2, default: "0.0", null: false
    t.date "due_on"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "payment_status", default: "unpaid", null: false
    t.boolean "prices_include_tax", default: true, null: false
    t.string "purchase_number", null: false
    t.date "purchased_on", null: false
    t.datetime "received_at", null: false
    t.bigint "recorded_by_id", null: false
    t.string "status", default: "received", null: false
    t.decimal "subtotal", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "supplier_id", null: false
    t.string "supplier_invoice_number"
    t.decimal "tax_total", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_purchases_on_branch_id"
    t.index ["organization_id", "payment_status"], name: "index_purchases_on_organization_id_and_payment_status"
    t.index ["organization_id", "purchase_number"], name: "index_purchases_on_organization_id_and_purchase_number", unique: true
    t.index ["organization_id", "purchased_on"], name: "index_purchases_on_organization_id_and_purchased_on"
    t.index ["organization_id", "supplier_id", "supplier_invoice_number"], name: "index_unique_supplier_purchase_invoice", unique: true, where: "((supplier_invoice_number IS NOT NULL) AND ((supplier_invoice_number)::text <> ''::text))"
    t.index ["organization_id"], name: "index_purchases_on_organization_id"
    t.index ["recorded_by_id"], name: "index_purchases_on_recorded_by_id"
    t.index ["supplier_id"], name: "index_purchases_on_supplier_id"
    t.check_constraint "amount_paid <= total", name: "purchases_amount_paid_not_above_total"
    t.check_constraint "due_on IS NULL OR due_on >= purchased_on", name: "purchases_due_date_valid"
    t.check_constraint "payment_status::text = ANY (ARRAY['unpaid'::character varying, 'partially_paid'::character varying, 'paid'::character varying]::text[])", name: "purchases_payment_status_valid"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'received'::character varying, 'cancelled'::character varying]::text[])", name: "purchases_status_valid"
    t.check_constraint "subtotal >= 0::numeric AND discount_total >= 0::numeric AND tax_total >= 0::numeric AND total >= 0::numeric AND amount_paid >= 0::numeric AND balance_due >= 0::numeric", name: "purchases_amounts_nonnegative"
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

  create_table "sale_return_lines", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.decimal "discount_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "gross_amount", precision: 15, scale: 2, null: false
    t.bigint "inventory_batch_id"
    t.bigint "item_id", null: false
    t.string "item_name", null: false
    t.string "item_type", null: false
    t.integer "line_number", null: false
    t.decimal "line_total", precision: 15, scale: 2, null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.decimal "quantity", precision: 15, scale: 4, null: false
    t.string "reason_code"
    t.bigint "sale_line_id", null: false
    t.bigint "sale_return_id", null: false
    t.string "sku"
    t.string "stock_disposition", default: "not_applicable", null: false
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "tax_rate_percentage", precision: 7, scale: 4, default: "0.0", null: false
    t.decimal "unit_cost", precision: 15, scale: 2, default: "0.0", null: false
    t.string "unit_name", null: false
    t.decimal "unit_price", precision: 15, scale: 2, null: false
    t.string "unit_symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_batch_id"], name: "index_sale_return_lines_on_inventory_batch_id"
    t.index ["item_id"], name: "index_sale_return_lines_on_item_id"
    t.index ["organization_id", "item_id"], name: "index_sale_return_lines_on_org_and_item"
    t.index ["organization_id"], name: "index_sale_return_lines_on_organization_id"
    t.index ["sale_line_id", "inventory_batch_id"], name: "index_sale_return_lines_on_source_and_batch"
    t.index ["sale_line_id"], name: "index_sale_return_lines_on_sale_line_id"
    t.index ["sale_return_id", "line_number"], name: "index_sale_return_lines_on_return_and_line", unique: true
    t.index ["sale_return_id"], name: "index_sale_return_lines_on_sale_return_id"
    t.check_constraint "discount_amount <= gross_amount", name: "sale_return_lines_discount_within_gross"
    t.check_constraint "item_type::text = ANY (ARRAY['product'::character varying, 'service'::character varying]::text[])", name: "sale_return_lines_item_type_valid"
    t.check_constraint "line_number > 0", name: "sale_return_lines_line_number_positive"
    t.check_constraint "line_total <= gross_amount", name: "sale_return_lines_total_within_gross"
    t.check_constraint "quantity > 0::numeric", name: "sale_return_lines_quantity_positive"
    t.check_constraint "stock_disposition::text = ANY (ARRAY['restock'::character varying, 'quarantine'::character varying, 'damaged'::character varying, 'expired'::character varying, 'not_applicable'::character varying]::text[])", name: "sale_return_lines_disposition_valid"
    t.check_constraint "tax_amount <= line_total", name: "sale_return_lines_tax_within_total"
    t.check_constraint "unit_price >= 0::numeric AND unit_cost >= 0::numeric AND gross_amount >= 0::numeric AND discount_amount >= 0::numeric AND tax_rate_percentage >= 0::numeric AND tax_amount >= 0::numeric AND line_total >= 0::numeric", name: "sale_return_lines_amounts_nonnegative"
  end

  create_table "sale_returns", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.decimal "discount_total", precision: 15, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "reason_code", default: "other", null: false
    t.text "reason_details"
    t.bigint "recorded_by_id", null: false
    t.string "return_number", null: false
    t.datetime "returned_at"
    t.bigint "sale_id", null: false
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "tax_total", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "returned_at"], name: "index_sale_returns_on_branch_and_time"
    t.index ["branch_id"], name: "index_sale_returns_on_branch_id"
    t.index ["organization_id", "return_number"], name: "index_sale_returns_on_org_and_number", unique: true
    t.index ["organization_id", "status"], name: "index_sale_returns_on_org_and_status"
    t.index ["organization_id"], name: "index_sale_returns_on_organization_id"
    t.index ["recorded_by_id"], name: "index_sale_returns_on_recorded_by_id"
    t.index ["sale_id", "returned_at"], name: "index_sale_returns_on_sale_and_time"
    t.index ["sale_id"], name: "index_sale_returns_on_sale_id"
    t.check_constraint "discount_total <= subtotal", name: "sale_returns_discount_within_subtotal"
    t.check_constraint "status::text <> 'completed'::text OR returned_at IS NOT NULL", name: "sale_returns_completed_has_time"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "sale_returns_status_valid"
    t.check_constraint "subtotal >= 0::numeric AND discount_total >= 0::numeric AND tax_total >= 0::numeric AND total >= 0::numeric", name: "sale_returns_amounts_nonnegative"
    t.check_constraint "tax_total <= total", name: "sale_returns_tax_within_total"
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
    t.date "due_on"
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
    t.index ["organization_id", "due_on"], name: "index_sales_on_organization_id_and_due_on"
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
    t.check_constraint "due_on IS NULL OR sold_at IS NULL OR due_on >= sold_at::date", name: "sales_due_date_not_before_sale"
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
    t.bigint "inventory_batch_id"
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
    t.index ["inventory_batch_id"], name: "index_stock_movements_on_inventory_batch_id"
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

  create_table "supplier_credits", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.decimal "applied_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "credit_number"
    t.date "issued_on"
    t.text "notes"
    t.bigint "organization_id", null: false
    t.bigint "purchase_return_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "credit_number"], name: "index_supplier_credits_on_org_and_number", unique: true, where: "((credit_number IS NOT NULL) AND ((credit_number)::text <> ''::text))"
    t.index ["organization_id", "status"], name: "index_supplier_credits_on_org_and_status"
    t.index ["organization_id"], name: "index_supplier_credits_on_organization_id"
    t.index ["purchase_return_id", "issued_on"], name: "index_supplier_credits_on_return_and_date"
    t.index ["purchase_return_id"], name: "index_supplier_credits_on_purchase_return_id"
    t.index ["recorded_by_id"], name: "index_supplier_credits_on_recorded_by_id"
    t.check_constraint "amount > 0::numeric", name: "supplier_credits_amount_positive"
    t.check_constraint "applied_amount >= 0::numeric AND applied_amount <= amount", name: "supplier_credits_applied_amount_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'available'::character varying, 'partially_applied'::character varying, 'applied'::character varying, 'cancelled'::character varying]::text[])", name: "supplier_credits_status_valid"
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

  add_foreign_key "accounting_account_mappings", "ledger_accounts"
  add_foreign_key "accounting_account_mappings", "organizations"
  add_foreign_key "branch_payment_settings", "branches"
  add_foreign_key "branch_payment_settings", "money_accounts"
  add_foreign_key "branch_payment_settings", "organizations"
  add_foreign_key "branch_payment_settings", "payment_methods"
  add_foreign_key "branches", "organizations"
  add_foreign_key "customer_refunds", "money_accounts"
  add_foreign_key "customer_refunds", "organizations"
  add_foreign_key "customer_refunds", "payment_methods"
  add_foreign_key "customer_refunds", "sale_returns"
  add_foreign_key "customer_refunds", "users", column: "recorded_by_id"
  add_foreign_key "customers", "organizations"
  add_foreign_key "inventory_batches", "branches"
  add_foreign_key "inventory_batches", "items"
  add_foreign_key "inventory_batches", "organizations"
  add_foreign_key "inventory_batches", "purchase_lines"
  add_foreign_key "items", "organizations"
  add_foreign_key "items", "product_categories"
  add_foreign_key "items", "tax_rates"
  add_foreign_key "items", "unit_of_measures"
  add_foreign_key "ledger_accounts", "ledger_accounts", column: "parent_id"
  add_foreign_key "ledger_accounts", "organizations"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "money_accounts", "branches"
  add_foreign_key "money_accounts", "ledger_accounts"
  add_foreign_key "money_accounts", "organizations"
  add_foreign_key "money_transfers", "money_accounts", column: "from_money_account_id"
  add_foreign_key "money_transfers", "money_accounts", column: "to_money_account_id"
  add_foreign_key "money_transfers", "organizations"
  add_foreign_key "money_transfers", "users", column: "recorded_by_id"
  add_foreign_key "payment_methods", "organizations"
  add_foreign_key "product_categories", "organizations"
  add_foreign_key "purchase_lines", "items"
  add_foreign_key "purchase_lines", "organizations"
  add_foreign_key "purchase_lines", "purchases"
  add_foreign_key "purchase_lines", "tax_rates"
  add_foreign_key "purchase_payments", "money_accounts"
  add_foreign_key "purchase_payments", "organizations"
  add_foreign_key "purchase_payments", "payment_methods"
  add_foreign_key "purchase_payments", "purchases"
  add_foreign_key "purchase_payments", "users", column: "recorded_by_id"
  add_foreign_key "purchase_return_lines", "inventory_batches"
  add_foreign_key "purchase_return_lines", "items"
  add_foreign_key "purchase_return_lines", "organizations"
  add_foreign_key "purchase_return_lines", "purchase_lines"
  add_foreign_key "purchase_return_lines", "purchase_returns"
  add_foreign_key "purchase_returns", "branches"
  add_foreign_key "purchase_returns", "organizations"
  add_foreign_key "purchase_returns", "purchases"
  add_foreign_key "purchase_returns", "users", column: "recorded_by_id"
  add_foreign_key "purchases", "branches"
  add_foreign_key "purchases", "organizations"
  add_foreign_key "purchases", "suppliers"
  add_foreign_key "purchases", "users", column: "recorded_by_id"
  add_foreign_key "sale_lines", "items"
  add_foreign_key "sale_lines", "organizations"
  add_foreign_key "sale_lines", "sales"
  add_foreign_key "sale_lines", "tax_rates"
  add_foreign_key "sale_payments", "money_accounts"
  add_foreign_key "sale_payments", "organizations"
  add_foreign_key "sale_payments", "payment_methods"
  add_foreign_key "sale_payments", "sales"
  add_foreign_key "sale_payments", "users", column: "recorded_by_id"
  add_foreign_key "sale_return_lines", "inventory_batches"
  add_foreign_key "sale_return_lines", "items"
  add_foreign_key "sale_return_lines", "organizations"
  add_foreign_key "sale_return_lines", "sale_lines"
  add_foreign_key "sale_return_lines", "sale_returns"
  add_foreign_key "sale_returns", "branches"
  add_foreign_key "sale_returns", "organizations"
  add_foreign_key "sale_returns", "sales"
  add_foreign_key "sale_returns", "users", column: "recorded_by_id"
  add_foreign_key "sales", "branches"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "organizations"
  add_foreign_key "sales", "users", column: "cashier_id"
  add_foreign_key "stock_levels", "branches"
  add_foreign_key "stock_levels", "items"
  add_foreign_key "stock_levels", "organizations"
  add_foreign_key "stock_movements", "branches"
  add_foreign_key "stock_movements", "inventory_batches"
  add_foreign_key "stock_movements", "items"
  add_foreign_key "stock_movements", "organizations"
  add_foreign_key "stock_movements", "users", column: "recorded_by_id"
  add_foreign_key "stock_transfers", "branches", column: "from_branch_id"
  add_foreign_key "stock_transfers", "branches", column: "to_branch_id"
  add_foreign_key "stock_transfers", "items"
  add_foreign_key "stock_transfers", "organizations"
  add_foreign_key "stock_transfers", "users", column: "recorded_by_id"
  add_foreign_key "supplier_credits", "organizations"
  add_foreign_key "supplier_credits", "purchase_returns"
  add_foreign_key "supplier_credits", "users", column: "recorded_by_id"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "tax_rates", "organizations"
  add_foreign_key "unit_of_measures", "organizations"
end
