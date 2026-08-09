class CreateReturnFoundation < ActiveRecord::Migration[8.1]
  def change
    add_return_sequences_to_branches
    create_sale_returns
    create_sale_return_lines
    create_customer_refunds
    create_purchase_returns
    create_purchase_return_lines
    create_supplier_credits
  end

  private

  def add_return_sequences_to_branches
    add_column :branches,
               :next_sale_return_sequence,
               :integer,
               default: 1,
               null: false

    add_column :branches,
               :next_purchase_return_sequence,
               :integer,
               default: 1,
               null: false

    add_check_constraint(
      :branches,
      "next_sale_return_sequence > 0",
      name: "branches_sale_return_sequence_positive"
    )

    add_check_constraint(
      :branches,
      "next_purchase_return_sequence > 0",
      name: "branches_purchase_return_sequence_positive"
    )
  end

  def create_sale_returns
    create_table :sale_returns do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :sale,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :return_number,
               null: false

      t.string :status,
               null: false,
               default: "draft"

      t.string :reason_code,
               null: false,
               default: "other"

      t.text :reason_details
      t.text :notes

      t.datetime :returned_at

      t.decimal :subtotal,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :discount_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.timestamps
    end

    add_index :sale_returns,
              %i[organization_id return_number],
              unique: true,
              name: "index_sale_returns_on_org_and_number"

    add_index :sale_returns,
              %i[organization_id status],
              name: "index_sale_returns_on_org_and_status"

    add_index :sale_returns,
              %i[branch_id returned_at],
              name: "index_sale_returns_on_branch_and_time"

    add_index :sale_returns,
              %i[sale_id returned_at],
              name: "index_sale_returns_on_sale_and_time"

    add_check_constraint(
      :sale_returns,
      <<~SQL.squish,
        status IN (
          'draft',
          'completed',
          'cancelled'
        )
      SQL
      name: "sale_returns_status_valid"
    )

    add_check_constraint(
      :sale_returns,
      <<~SQL.squish,
        subtotal >= 0 AND
        discount_total >= 0 AND
        tax_total >= 0 AND
        total >= 0
      SQL
      name: "sale_returns_amounts_nonnegative"
    )

    add_check_constraint(
      :sale_returns,
      "discount_total <= subtotal",
      name: "sale_returns_discount_within_subtotal"
    )

    add_check_constraint(
      :sale_returns,
      "tax_total <= total",
      name: "sale_returns_tax_within_total"
    )

    add_check_constraint(
      :sale_returns,
      <<~SQL.squish,
        status <> 'completed' OR
        returned_at IS NOT NULL
      SQL
      name: "sale_returns_completed_has_time"
    )
  end

  def create_sale_return_lines
    create_table :sale_return_lines do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :sale_return,
                   null: false,
                   foreign_key: true

      t.references :sale_line,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :inventory_batch,
                   null: true,
                   foreign_key: true

      t.integer :line_number,
                null: false

      t.string :item_name,
               null: false

      t.string :sku
      t.string :barcode

      t.string :item_type,
               null: false

      t.string :unit_name,
               null: false

      t.string :unit_symbol,
               null: false

      t.decimal :quantity,
                precision: 15,
                scale: 4,
                null: false

      t.decimal :unit_price,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :unit_cost,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :gross_amount,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :discount_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_rate_percentage,
                precision: 7,
                scale: 4,
                null: false,
                default: 0

      t.decimal :tax_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :line_total,
                precision: 15,
                scale: 2,
                null: false

      t.string :stock_disposition,
               null: false,
               default: "not_applicable"

      t.string :reason_code
      t.text :notes

      t.timestamps
    end

    add_index :sale_return_lines,
              %i[sale_return_id line_number],
              unique: true,
              name: "index_sale_return_lines_on_return_and_line"

    add_index :sale_return_lines,
              %i[organization_id item_id],
              name: "index_sale_return_lines_on_org_and_item"

    add_index :sale_return_lines,
              %i[sale_line_id inventory_batch_id],
              name: "index_sale_return_lines_on_source_and_batch"

    add_check_constraint(
      :sale_return_lines,
      "line_number > 0",
      name: "sale_return_lines_line_number_positive"
    )

    add_check_constraint(
      :sale_return_lines,
      "quantity > 0",
      name: "sale_return_lines_quantity_positive"
    )

    add_check_constraint(
      :sale_return_lines,
      <<~SQL.squish,
        unit_price >= 0 AND
        unit_cost >= 0 AND
        gross_amount >= 0 AND
        discount_amount >= 0 AND
        tax_rate_percentage >= 0 AND
        tax_amount >= 0 AND
        line_total >= 0
      SQL
      name: "sale_return_lines_amounts_nonnegative"
    )

    add_check_constraint(
      :sale_return_lines,
      "discount_amount <= gross_amount",
      name: "sale_return_lines_discount_within_gross"
    )

    add_check_constraint(
      :sale_return_lines,
      "line_total <= gross_amount",
      name: "sale_return_lines_total_within_gross"
    )

    add_check_constraint(
      :sale_return_lines,
      "tax_amount <= line_total",
      name: "sale_return_lines_tax_within_total"
    )

    add_check_constraint(
      :sale_return_lines,
      <<~SQL.squish,
        item_type IN (
          'product',
          'service'
        )
      SQL
      name: "sale_return_lines_item_type_valid"
    )

    add_check_constraint(
      :sale_return_lines,
      <<~SQL.squish,
        stock_disposition IN (
          'restock',
          'quarantine',
          'damaged',
          'expired',
          'not_applicable'
        )
      SQL
      name: "sale_return_lines_disposition_valid"
    )
  end

  def create_customer_refunds
    create_table :customer_refunds do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :sale_return,
                   null: false,
                   foreign_key: true

      t.references :payment_method,
                   null: false,
                   foreign_key: true

      t.references :money_account,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.decimal :amount,
                precision: 15,
                scale: 2,
                null: false

      t.datetime :refunded_at,
                 null: false

      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_index :customer_refunds,
              %i[sale_return_id refunded_at],
              name: "index_customer_refunds_on_return_and_time"

    add_index :customer_refunds,
              %i[organization_id refunded_at],
              name: "index_customer_refunds_on_org_and_time"

    add_index :customer_refunds,
              %i[organization_id money_account_id],
              name: "index_customer_refunds_on_org_and_account"

    add_check_constraint(
      :customer_refunds,
      "amount > 0",
      name: "customer_refunds_amount_positive"
    )
  end

  def create_purchase_returns
    create_table :purchase_returns do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :purchase,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :return_number,
               null: false

      t.string :status,
               null: false,
               default: "draft"

      t.string :reason_code,
               null: false,
               default: "other"

      t.string :supplier_document_number
      t.text :reason_details
      t.text :notes

      t.datetime :returned_at

      t.decimal :subtotal,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :discount_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.timestamps
    end

    add_index :purchase_returns,
              %i[organization_id return_number],
              unique: true,
              name: "index_purchase_returns_on_org_and_number"

    add_index :purchase_returns,
              %i[organization_id status],
              name: "index_purchase_returns_on_org_and_status"

    add_index :purchase_returns,
              %i[branch_id returned_at],
              name: "index_purchase_returns_on_branch_and_time"

    add_index :purchase_returns,
              %i[purchase_id returned_at],
              name: "index_purchase_returns_on_purchase_and_time"

    add_check_constraint(
      :purchase_returns,
      <<~SQL.squish,
        status IN (
          'draft',
          'completed',
          'cancelled'
        )
      SQL
      name: "purchase_returns_status_valid"
    )

    add_check_constraint(
      :purchase_returns,
      <<~SQL.squish,
        subtotal >= 0 AND
        discount_total >= 0 AND
        tax_total >= 0 AND
        total >= 0
      SQL
      name: "purchase_returns_amounts_nonnegative"
    )

    add_check_constraint(
      :purchase_returns,
      "discount_total <= subtotal",
      name: "purchase_returns_discount_within_subtotal"
    )

    add_check_constraint(
      :purchase_returns,
      "tax_total <= total",
      name: "purchase_returns_tax_within_total"
    )

    add_check_constraint(
      :purchase_returns,
      <<~SQL.squish,
        status <> 'completed' OR
        returned_at IS NOT NULL
      SQL
      name: "purchase_returns_completed_has_time"
    )
  end

  def create_purchase_return_lines
    create_table :purchase_return_lines do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :purchase_return,
                   null: false,
                   foreign_key: true

      t.references :purchase_line,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :inventory_batch,
                   null: true,
                   foreign_key: true

      t.integer :line_number,
                null: false

      t.string :item_name,
               null: false

      t.string :sku
      t.string :barcode

      t.string :item_type,
               null: false

      t.string :unit_name,
               null: false

      t.string :unit_symbol,
               null: false

      t.decimal :quantity,
                precision: 15,
                scale: 4,
                null: false

      t.decimal :unit_cost,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :gross_amount,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :discount_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_percentage,
                precision: 7,
                scale: 4,
                null: false,
                default: 0

      t.decimal :tax_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :line_total,
                precision: 15,
                scale: 2,
                null: false

      t.string :reason_code
      t.text :notes

      t.timestamps
    end

    add_index :purchase_return_lines,
              %i[purchase_return_id line_number],
              unique: true,
              name: "index_purchase_return_lines_on_return_and_line"

    add_index :purchase_return_lines,
              %i[organization_id item_id],
              name: "index_purchase_return_lines_on_org_and_item"

    add_index :purchase_return_lines,
              %i[purchase_line_id inventory_batch_id],
              name: "index_purchase_return_lines_on_source_and_batch"

    add_check_constraint(
      :purchase_return_lines,
      "line_number > 0",
      name: "purchase_return_lines_line_number_positive"
    )

    add_check_constraint(
      :purchase_return_lines,
      "quantity > 0",
      name: "purchase_return_lines_quantity_positive"
    )

    add_check_constraint(
      :purchase_return_lines,
      <<~SQL.squish,
        unit_cost >= 0 AND
        gross_amount >= 0 AND
        discount_amount >= 0 AND
        tax_percentage >= 0 AND
        tax_amount >= 0 AND
        line_total >= 0
      SQL
      name: "purchase_return_lines_amounts_nonnegative"
    )

    add_check_constraint(
      :purchase_return_lines,
      "discount_amount <= gross_amount",
      name: "purchase_return_lines_discount_within_gross"
    )

    add_check_constraint(
      :purchase_return_lines,
      "line_total <= gross_amount",
      name: "purchase_return_lines_total_within_gross"
    )

    add_check_constraint(
      :purchase_return_lines,
      "tax_amount <= line_total",
      name: "purchase_return_lines_tax_within_total"
    )

    add_check_constraint(
      :purchase_return_lines,
      <<~SQL.squish,
        item_type IN (
          'product',
          'service'
        )
      SQL
      name: "purchase_return_lines_item_type_valid"
    )
  end

  def create_supplier_credits
    create_table :supplier_credits do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :purchase_return,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :credit_number

      t.string :status,
               null: false,
               default: "pending"

      t.date :issued_on

      t.decimal :amount,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :applied_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.text :notes

      t.timestamps
    end

    add_index :supplier_credits,
              %i[organization_id credit_number],
              unique: true,
              where:
                "credit_number IS NOT NULL AND " \
                "credit_number <> ''",
              name: "index_supplier_credits_on_org_and_number"

    add_index :supplier_credits,
              %i[organization_id status],
              name: "index_supplier_credits_on_org_and_status"

    add_index :supplier_credits,
              %i[purchase_return_id issued_on],
              name: "index_supplier_credits_on_return_and_date"

    add_check_constraint(
      :supplier_credits,
      <<~SQL.squish,
        status IN (
          'pending',
          'available',
          'partially_applied',
          'applied',
          'cancelled'
        )
      SQL
      name: "supplier_credits_status_valid"
    )

    add_check_constraint(
      :supplier_credits,
      "amount > 0",
      name: "supplier_credits_amount_positive"
    )

    add_check_constraint(
      :supplier_credits,
      <<~SQL.squish,
        applied_amount >= 0 AND
        applied_amount <= amount
      SQL
      name: "supplier_credits_applied_amount_valid"
    )
  end
end
