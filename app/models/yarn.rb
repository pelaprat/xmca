class Yarn < ActiveRecord::Base
  belongs_to :person
  has_many :messages

  validates :name,   :presence => true
  validates :items,  :presence => true
  validates :person, :presence => true
end
