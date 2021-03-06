class GroupItem < ApplicationRecord
  include GroupItem::Search
  include ::Sortable

  versionable

  before_validation :ensure_estimated_cost
  before_validation :ensure_available_quantity, on: :create

  attribute :estimated_cost, :money

  belongs_to :group, counter_cache: true
  belongs_to :item
  has_one :classification, through: :item, source: :classification
  has_one :unit, through: :item, source: :unit

  has_many :lot_group_items, dependent: :restrict_with_error
  has_many :proposals, through: :lot_group_items, source: :proposals
  has_many :accepted_lot_group_item_lot_proposals, -> { where(proposals: { status: 'accepted' }).distinct }, through: :proposals, source: :lot_group_item_lot_proposals

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :available_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :estimated_cost, presence: true, numericality: { greater_than: 0 }

  validates_uniqueness_of :item_id, scope: :group_id

  scope :by_covenant, -> (covenant_id) do
    joins(:group).
      select('group_items.*, groups.name').
      where(groups: { covenant_id: covenant_id }).
      order('groups.name')
  end

  def text
    item.text
  end

  private

  def ensure_estimated_cost
    self.estimated_cost = estimated_cost_before_type_cast.to_s.gsub(',', '.').to_f
  end

  def ensure_available_quantity
    self.available_quantity = quantity
  end

  def self.default_sort_column
    'items.title'
  end

  def self.sort_associations
    :item
  end

  def self.by_proposals_accepted
    joins(:proposals).where(proposals: { status: :accepted })
  end

end
