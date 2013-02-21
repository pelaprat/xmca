class PeopleController < ApplicationController
  include ApplicationHelper

  helper_method :order_column, :sort_column

  def show
    @person   = Person.find(params[:id])
    @messages = @person.messages.order(order_column + ' ' + sort_column).page(params[:page]).per(30)
    @keywords = get_keyword_array( params )

    page_controller = 'person'

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @person }
    end
  end

  private

  def order_column
    Yarn.column_names.include?(params[:order]) ? params[:order] : 'updated_at'
  end

  def sort_column
    %w[asc desc].include?(params[:sort]) ? params[:sort] : 'desc'
  end
end
