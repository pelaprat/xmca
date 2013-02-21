# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
EduUcsdXmca::Application.initialize!

WillPaginate::ViewHelpers.pagination_options[:prev_label] = '&laquo; Prev'
WillPaginate::ViewHelpers.pagination_options[:next_label] = 'Next &raquo;'