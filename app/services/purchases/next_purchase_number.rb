module Purchases
  class NextPurchaseNumber
    def self.call(branch:)
      new(branch: branch).call
    end

    def initialize(branch:)
      @branch = branch
    end

    def call
      branch.with_lock do
        sequence =
          branch.next_purchase_sequence

        branch.update!(
          next_purchase_sequence:
            sequence + 1
        )

        "#{branch_code}-PUR-" \
          "#{sequence.to_s.rjust(6, '0')}"
      end
    end

    private

    attr_reader :branch

    def branch_code
      branch.code.presence ||
        "BR#{branch.id}"
    end
  end
end
