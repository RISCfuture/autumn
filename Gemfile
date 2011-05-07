source :rubygems

gem 'daemons'
gem 'anise'

group :pre_config do
  gem 'i18n'
  gem 'activesupport', :require => 'active_support/core_ext/string'
  gem 'facets'
end

# Only loaded if a database.yml file exists for a season
group :datamapper do
  gem 'dm-sqlite-adapter', '< 1.1.0' # Change this to whatever adapter you need for your database
  gem 'dm-core', '< 1.1.0'
  gem 'dm-migrations', '< 1.1.0'
end

# load each leaf's gem requirements in its own group
Dir.glob("#{File.dirname __FILE__}/leaves/*/Gemfile").each do |gemfile|
  eval File.read(gemfile)
end

# Season-specific gem requirements:
#
# group :season_name do
#  gem 'my-gem'
# end
