class Person < ActiveRecord::Base
  has_many :messages
  has_many :yarns

  def full_name 
    self.first + ' ' + self.last
  end
end
