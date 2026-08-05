require "test_helper"

module Sales
  class NextSaleNumberTest < ActiveSupport::TestCase
    setup do
      @organization =
        provision_organization_for(create_user)

      @branch = @organization.main_branch

      @branch.update!(
        next_sale_sequence: 1
      )
    end

    test "generates sequential branch sale numbers" do
      first_number =
        Sales::NextSaleNumber.call(
          branch: @branch
        )

      second_number =
        Sales::NextSaleNumber.call(
          branch: @branch
        )

      assert_equal "MAIN-000001",
                   first_number

      assert_equal "MAIN-000002",
                   second_number

      assert_equal 3,
                   @branch.reload.next_sale_sequence
    end

    test "sequence increment rolls back with transaction" do
      assert_raises(RuntimeError) do
        Sale.transaction do
          Sales::NextSaleNumber.call(
            branch: @branch
          )

          raise "Force rollback"
        end
      end

      assert_equal 1,
                   @branch.reload.next_sale_sequence
    end
  end
end
