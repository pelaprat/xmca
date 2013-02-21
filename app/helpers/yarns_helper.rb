module YarnsHelper
  def print_body( body )
    if body.level == 0
      simple_format( auto_link(body.original_newline))
    elsif body.level < 999
      simple_format( auto_link(body.original_newline))
    end
  end
end
