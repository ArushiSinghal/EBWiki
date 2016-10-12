class Agency < ActiveRecord::Base
  has_many :case_agencies
  has_many :cases, through: :case_agencies
  belongs_to :state

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :state_id, presence: true

  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  # Try building a slug based on the following fields in
  # increasing order of specificity.
  def slug_candidates
    [
      :name,
      [:name, :city],
      [:name, :street_address, :city],
    ]
  end
end
