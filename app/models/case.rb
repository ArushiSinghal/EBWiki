# frozen_string_literal: true

# This is still called "Case", although its true name is "Case"
# TODO: Rename this to Case
#
class Case < ActiveRecord::Base
  # TODO: Clean up relationship section
  belongs_to :user
  belongs_to :category
  belongs_to :state
  has_many :links, dependent: :destroy
  accepts_nested_attributes_for :links, reject_if: :all_blank, allow_destroy: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :subjects, dependent: :destroy
  accepts_nested_attributes_for :subjects, reject_if: :all_blank, allow_destroy: true

  has_many :case_agencies, dependent: :destroy
  has_many :agencies, through: :case_agencies
  accepts_nested_attributes_for :case_agencies, reject_if: :all_blank, allow_destroy: true
  # Paper Trail
  has_paper_trail ignore: [:summary], meta: { comment: :edit_summary }

  # Acts as Follows, for follower functionality
  acts_as_followable

  # Friendly ID
  extend FriendlyId
  friendly_id :slug_candidates, use: %i[slugged finders]

  # Elasticsearch Gem
  searchkick

  # Model Validations
  validates :date, presence: { message: 'Please add a date.' }
  validate :article_date_cannot_be_in_the_future
  validates :city, presence: { message: 'Please add a city.' }
  validates :state_id, presence: { message: 'Please specify the state where this incident occurred before saving.' }
  validates :title, presence: { message: 'Please specify a title' }
  validates_associated :subjects
  validates :subjects, presence: { message: 'at least one subject is required' }
  validates :summary, presence: { message: 'Please use the last field at the bottom of this form to summarize your edits to the article.' }

  # Avatar uploader using carrierwave
  mount_uploader :avatar, AvatarUploader

  # before_validation :check_for_empty_fields

  # Geocoding
  geocoded_by :full_address
  before_save :geocode, if: proc { |art|
    art.address_changed? || art.city_changed? || art.state_id_changed? || art.zipcode_changed?
  } # auto-fetch coordinates

  before_save :set_default_avatar_url if proc do |this_case|
    this_case.avatar.changed?
  end
  # Scopes
  scope :this_month, -> { where(created_at: 1.month.ago.beginning_of_day..Date.today.end_of_day) }
  scope :property_count_over_time, ->(property, days) { where("#{property}": days.to_s.to_i.days.ago..Time.now).count }

  def full_address
    "#{address} #{city} #{state.ansi_code} #{zipcode}".strip
  end

  def set_default_avatar_url
    self.default_avatar_url = avatar.url
  end

  def self.find_by_search(query)
    search(query)
  end

  def nearby_cases
    try(:nearbys, 50).try(:order, 'distance')
  end

  def article_date_cannot_be_in_the_future
    if date.present? && date > Date.today
      errors.add(:date, 'must be in the past')
    end
  end

  def edit_summary
    summary
  end

  # Try building a slug based on the following fields in
  # increasing order of specificity.
  def slug_candidates
    [
      :title,
      %i[title city],
      %i[title city zipcode]
    ]
  end

  def mom_new_cases_growth
    last_month_cases = Case.property_count_over_time('date', 30)
    last_60_days_cases = Case.property_count_over_time('date', 60)
    prior_30_days_cases = last_60_days_cases - last_month_cases

    (((last_month_cases.to_f / prior_30_days_cases) - 1) * 100).round(2)
  end

  def mom_cases_growth
    last_month_cases = Case.property_count_over_time('created_at', 30)

    (last_month_cases.to_f / (Case.count - last_month_cases) * 100).round(2)
  end

  def cases_updated_last_30_days
    Case.property_count_over_time('updated_at', 30)
  end

  def mom_growth_in_case_updates
    last_month_case_updates = Case.property_count_over_time('updated_at', 30)
    last_60_days_case_updates = Case.property_count_over_time('updated_at', 60)
    prior_30_days_case_updates = last_60_days_case_updates - last_month_case_updates

    (((last_month_case_updates.to_f / prior_30_days_case_updates) - 1) * 100).round(2)
  end

  private

  def check_for_empty_fields
    attrs = %w[title date address city state zipcode state_id avatar video_url overview community_action litigation country remove_avatar]

    unless (changed & attrs).any?
      errors[:base] << 'You must change field other than summary to generate a new version'
    end
  end
end
