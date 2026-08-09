require "test_helper"

module Returns
  class NextReturnNumberTest <
    ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch =
        @organization.main_branch
    end

    test "generates sequential sale return numbers" do
      first =
        Returns::NextSaleReturnNumber.call(
          branch: @branch
        )

      second =
        Returns::NextSaleReturnNumber.call(
          branch: @branch
        )

      assert_match(
        /-SRET-000001\z/,
        first
      )

      assert_match(
        /-SRET-000002\z/,
        second
      )

      assert_equal(
        3,
        @branch
          .reload
          .next_sale_return_sequence
      )
    end

    test "generates sequential purchase return numbers" do
      first =
        Returns::NextPurchaseReturnNumber.call(
          branch: @branch
        )

      second =
        Returns::NextPurchaseReturnNumber.call(
          branch: @branch
        )

      assert_match(
        /-PRET-000001\z/,
        first
      )

      assert_match(
        /-PRET-000002\z/,
        second
      )

      assert_equal(
        3,
        @branch
          .reload
          .next_purchase_return_sequence
      )
    end

    test "sale and purchase return sequences are independent" do
      sale_return_number =
        Returns::NextSaleReturnNumber.call(
          branch: @branch
        )

      purchase_return_number =
        Returns::NextPurchaseReturnNumber.call(
          branch: @branch
        )

      assert_match(
        /-SRET-000001\z/,
        sale_return_number
      )

      assert_match(
        /-PRET-000001\z/,
        purchase_return_number
      )
    end
  end
end
