module ApplicationHelper

  def get_keyword_array( a )
    if a[:keywords]
      a[:keywords].split( /\s+/ )
    elsif a[:message]
      if a[:message][:keywords]
        a[:message][:keywords].split( /\s+ / )
      else
        []
      end
    else
      []
    end
  end

  def sortable( column, title = nil )
    title ||= column.titleize
    css_class = column == order_column ?  "current #{sort_column}" : nil
    sort = column == order_column && sort_column == 'asc' ? 'desc' : 'asc'
    link_to title, {:order => column, :sort => sort}, {:class => css_class}
  end

  def yarn_page_number
    page_number
  end
end
