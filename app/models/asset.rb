class Asset < ActiveRecord::Base
  belongs_to :message

  @@attachments = '/Users/web/Sites/edu.ucsd.xmca/attachments'

  def download_path
      @@attachments + '/' + self.id.to_s + '/' + self.name
  end

end
