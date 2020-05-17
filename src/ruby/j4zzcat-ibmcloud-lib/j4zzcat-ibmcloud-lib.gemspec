Gem::Specification.new do | gem |
  gem.name         = 'j4zzcat-ibmcloud-lib'
  gem.version      = '0.1.0'

  gem.required_ruby_version = '>= 2.7'

  gem.summary      = 'Toolkit for easily interacting with IBM Cloud'
  gem.description  = <<~END
    Non at this time
    END
  gem.homepage     = 'https://github.com/j4zzcat/j4zzcat-ibmcloud-lib'
  gem.authors      = [ 'Sharon Dagan' ]
  gem.email        = [ 'sharon.dagan@il.ibm.com' ]
  gem.license      = 'GPL v3'
  gem.metadata     = {
    'bug_tracker_uri'   => 'https://github.com/j4zzcat/j4zzcat-ibmcloud-libissues',
    'changelog_uri'     => 'https://github.com/j4zzcat/j4zzcat-ibmcloud-lib/blob/master/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/j4zzcat/j4zzcat-ibmcloud-lib',
    'source_code_uri'   => 'https://github.com/j4zzcat/j4zzcat-ibmcloud-lib'
  }

  gem.files        = Dir[ '*.md', 'j4zzcat-ibmcloud-lib.*', 'Gemfile', 'lib/**/*.rb', 'resource/**/*' ]
  gem.require_path = 'lib'

  gem.add_dependency 'log4r',    '1.1.11'
  gem.add_dependency 'docopt',   '0.6.1'

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
end
