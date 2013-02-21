class Body < ActiveRecord::Base
  belongs_to :message

  def original_newline
    x = self.original.gsub(/\-{3,}/, "<hr size=1>")
    x = self.original.gsub(/\_{3,}/, "<hr size=1>")
    return x.gsub(/\n/, "<br>")
  end


end
