# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name         = 'capistrano-drupal-deploy'
  spec.version      = '0.0.2'
  spec.license      = 'MIT'
  spec.authors  = [ "Frank Henry" ]
  spec.email    = 'frank.henry@frankcommunication.ie'
  spec.homepage = %q{https://github.com/frankhenry/drupal-deploy}
  spec.platform     = Gem::Platform::RUBY
  spec.description  = <<-DESC
    A set of tasks for deploying Drupal 7 and 8 projects with Capistrano 3 and the help of Drush.
  DESC
  spec.summary      = 'A set of tasks for deploying Drupal 7 and 8 projects with Capistrano'

  spec.extra_rdoc_files = [
    "README.markdown"
  ]

  spec.files = `git ls-files`.split($/)

  spec.require_path = 'lib'

  spec.add_dependency 'capistrano', '~> 3.2', '>= 3.2.0'
  spec.add_dependency 'capistrano-composer', '~> 0.0.6'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.4'


end
