class YarnsController < ApplicationController
  include ApplicationHelper

  helper_method :page_number
  
  # GET /yarns
  # GET /yarns.xml
  def index
    @yarns = Yarn.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @yarns }
    end
  end

  # GET /yarns/1
  # GET /yarns/1.xml
  def show
    @yarn     = Yarn.find(params[:id])
    @messages = @yarn.messages.order(:created_at)
    @keywords = get_keyword_array( params )

    ################################
    ## Highlight all the keywords ##
    @messages.each do |message|
      message.bodies.each do |body|
        @keywords.each do |keyword|
          body.original.gsub!( /(#{keyword})/, ' <span class="keyword">\1</span> ')
        end
      end
    end

    ############################
    ## Grab the participants. ##
    @participants = []
    @messages.each do |message|
      @participants.push message.person
    end
    @participants.uniq!

    ###########################
    ## Grab the attachments. ##
    @assets = []
    @messages.each do |message|
      message.assets.each do |asset|
        @assets.push asset
      end
    end
    @assets.uniq!

  end

  # GET /yarns/new
  # GET /yarns/new.xml
  def new
    @yarn = Yarn.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @yarn }
    end
  end

  # GET /yarns/1/edit
  def edit
    @yarn = Yarn.find(params[:id])
  end

  # POST /yarns
  # POST /yarns.xml
  def create
    @yarn = Yarn.new(params[:yarn])

    respond_to do |format|
      if @yarn.save
        format.html { redirect_to(@yarn, :notice => 'Yarn was successfully created.') }
        format.xml  { render :xml => @yarn, :status => :created, :location => @yarn }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @yarn.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /yarns/1
  # PUT /yarns/1.xml
  def update
    @yarn = Yarn.find(params[:id])

    respond_to do |format|
      if @yarn.update_attributes(params[:yarn])
        format.html { redirect_to(@yarn, :notice => 'Yarn was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @yarn.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /yarns/1
  # DELETE /yarns/1.xml
  def destroy
    @yarn = Yarn.find(params[:id])
    @yarn.destroy

    respond_to do |format|
      format.html { redirect_to(yarns_url) }
      format.xml  { head :ok }
    end
  end
  
  private

  def page_number
    params[:page] ? params[:page] : 1
  end
end
