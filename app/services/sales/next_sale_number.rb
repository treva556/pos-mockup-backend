module Sales
  class NextSaleNumber
    NUMBER_LENGTH = 6

    def self.call(branch:)
      new(branch: branch).call
    end

    def initialize(branch:)
      @branch = branch
    end

    def call
      validate_branch!

      branch.with_lock do
        sequence = branch.next_sale_sequence

        unless sequence&.positive?
          raise ArgumentError,
                "Branch sale sequence must be positive"
        end

        branch.update!(
          next_sale_sequence: sequence + 1
        )

        format_sale_number(sequence)
      end
    end

    private

    attr_reader :branch

    def validate_branch!
      unless branch&.persisted?
        raise ArgumentError,
              "A saved branch is required"
      end

      return if branch.code.to_s.strip.present?

      raise ArgumentError,
            "Branch code is required"
    end

    def format_sale_number(sequence)
      prefix = branch.code.to_s.strip.upcase

      formatted_sequence =
        sequence
          .to_s
          .rjust(NUMBER_LENGTH, "0")

      "#{prefix}-#{formatted_sequence}"
    end
  end
end
