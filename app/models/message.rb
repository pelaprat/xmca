class Message < ActiveRecord::Base
  belongs_to :yarn
  belongs_to :person

  has_many :assets
  has_many :bodies

  def self.search_us( keywords, page )
    Message.search keywords, :order => :id, :per_page => 30, :page => page
  end

  define_index do
    indexes subject, :sortable => true
    indexes updated_at, :sortable => true

    indexes assets(:name), :as => :asset_name, :sortable => true
    indexes bodies(:original), :as => :body_original, :sortable => true
    indexes [person.first, person.last], :as => :person_name, :sortable => true

    where " bodies.level = 0 "

    has :id
  end

  sphinx_scope( :latest_first ) {
    { :order => 'updated_at DESC'}
  }

  default_sphinx_scope :latest_first
end
