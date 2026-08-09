require "test_helper"

class MembershipReturnPermissionsTest <
  ActiveSupport::TestCase
  ROLES = %w[
    owner
    admin
    manager
    accountant
    cashier
    stock_clerk
  ].freeze

  test "sales return management permissions" do
    assert_permissions(
      :sales_return_management?,
      allowed: %w[
        owner
        admin
        manager
        cashier
      ]
    )
  end

  test "customer refund management permissions" do
    assert_permissions(
      :customer_refund_management?,
      allowed: %w[
        owner
        admin
        manager
        accountant
      ]
    )
  end

  test "purchase return management permissions" do
    assert_permissions(
      :purchase_return_management?,
      allowed: %w[
        owner
        admin
        manager
        stock_clerk
      ]
    )
  end

  test "supplier credit management permissions" do
    assert_permissions(
      :supplier_credit_management?,
      allowed: %w[
        owner
        admin
        manager
        accountant
      ]
    )
  end

  test "sales return view follows sales view permission" do
    ROLES.each do |role|
      membership = membership_for(role)

      assert_equal(
        membership.sales_view?,
        membership.sales_return_view?,
        role
      )
    end
  end

  test "purchase return view follows supplier account permission" do
    ROLES.each do |role|
      membership = membership_for(role)

      assert_equal(
        membership.supplier_account_view?,
        membership.purchase_return_view?,
        role
      )
    end
  end

  private

  def assert_permissions(method_name, allowed:)
    ROLES.each do |role|
      membership =
        membership_for(role)

      expected =
        allowed.include?(role)

      assert_equal(
        expected,
        membership.public_send(method_name),
        "#{role} #{method_name}"
      )
    end
  end

  def membership_for(role)
    Membership.new(
      role: role
    )
  end
end
