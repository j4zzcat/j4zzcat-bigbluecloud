$LOAD_PATH.push File.expand_path( '../lib', __dir__ )
require File.expand_path( 'lib/bigbluecloud/version.rb', __dir__ )

Gem::Specification.new do | gem |
  gem.name         = 'bigbluecloud'
  gem.version      = BigBlueCloud::VERSION

  gem.required_ruby_version = '>= 2.7'

  gem.summary      = 'Toolkit for easily interacting with the IBM Cloud'
  gem.description  = <<~END
    None at this time
    END
  gem.homepage     = 'https://github.com/j4zzcat/j4zzcat-bigbluecloud'
  gem.authors      = [ 'Sharon Dagan' ]
  gem.email        = [ 'sharon.dagan@gmail.com' ]
  gem.license      = 'GPL v3'
  gem.metadata     = {
    'bug_tracker_uri'   => 'https://github.com/j4zzcat/j4zzcat-bigbluecloud/issues',
    'changelog_uri'     => 'https://github.com/j4zzcat/j4zzcat-bigbluecloud/blob/master/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/j4zzcat/j4zzcat-bigbluecloud',
    'source_code_uri'   => 'https://github.com/j4zzcat/j4zzcat-bigbluecloud'
  }

  gem.files        = Dir[ '*.md', '*.gemspec', 'Gemfile', 'lib/**/*.rb', 'resource/**/*' ]
  gem.require_path = 'lib'

  gem.add_dependency 'log4r',           '1.1.10'
  gem.add_dependency 'docopt',          '0.6.1'
  gem.add_dependency 'smash_the_state', '1.4.0'

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
end
