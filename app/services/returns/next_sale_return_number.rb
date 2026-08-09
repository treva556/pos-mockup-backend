module Returns
  class NextSaleReturnNumber
    def self.call(branch:)
      new(branch: branch).call
    end

    def initialize(branch:)
      @branch = branch
    end

    def call
      validate_branch!

      branch.with_lock do
        sequence =
          branch.next_sale_return_sequence

        branch.update!(
          next_sale_return_sequence:
            sequence + 1
        )

        [
          branch.code,
          "SRET",
          sequence.to_s.rjust(6, "0")
        ].join("-")
      end
    end

    private

    attr_reader :branch

    def validate_branch!
      unless branch&.persisted?
        raise ArgumentError,
              "A saved branch is required"
      end

      return if branch.code.present?

      raise ArgumentError,
            "The branch must have a code"
    end
  end
end
