class Organization < ApplicationRecord
  has_many :branches, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :country_code, presence: true
  validates :currency_code, presence: true
  validates :time_zone, presence: true

  scope :active, -> { where(active: true) }

  def main_branch
    branches.find_by(main: true)
  end
end