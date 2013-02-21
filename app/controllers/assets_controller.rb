class AssetsController < ApplicationController

  def index

  end

  def download
    @asset = Asset.find(params[:id]);
    send_file @asset.download_path, :x_sendfile => true
  end


end
