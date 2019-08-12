# Capistrano::DrupalDeploy

Deploy [Drupal](https://www.drupal.org/) with [Capistrano v3](http://capistranorb.com/). This gem is a plugin for Capistrano that provides a number of tasks specific to Drupal. It is forked from [github.com/unitedworldwrestling/drupal-deploy](https://github.com/unitedworldwrestling/drupal-deploy). The main difference is this version works with both Drupal 7 and Drupal 8. It does this by creating wrappers around drush commands whose syntax in Drupal 8 is different to what it is in Drupal 7. 

For example, the command to put a Drupal 7 site into maintenance mode is

```
drush vset maintenance_mode 1
```

but on Drupal 8 it is 

```
drush state-set system.maintenance_mode 0 -y
```

With this project, the following command will work with both Drupal versions:

```
cap <stage-name> drupal:site_offline
```

If you are new to Capistrano check the [Capistrano 3 documentation](http://capistranorb.com/).

## Installation
[gems](http://rubygems.org) must be installed on your system first.

Add this line to your application's Gemfile:

```ruby
source 'https://rubygems.org'
group :development do
	gem "capistrano-drupal-deploy", "~> 0.0.3", git: 'https://github.com/frankhenry/drupal-deploy'
end
```

To install:

    $ gem install capistrano-drupal-deploy
    $ cap install

## Usage	

Require the module in your `Capfile`:

```ruby
require 'capistrano/drupal-deploy'
```

### Configuration

Edit `config/deploy.rb` to set the global parameters. You should at least edit your `app_name` and your `repo_url`.

```ruby
 set :application, 'my_app_name'
 set :repo_url, 'git@example.com:me/my_repo.git'
```

*Capistrano drupal deploy* makes the following configuration variables available. Specify these in the `deploy.rb` file in your project root folder.

```ruby
# Path to the drupal directory, default to app.
set :app_path,        "web"
```

This forked version adds another variable to specify the Drupal version. This is what enables it to work with both Drupal 7 and Drupal 8.

```ruby
# Drupal version
set: drupal_version,    "7"
```

Set up the `linked_dirs` variable to create a common private files folder for sharing across deployments.

```ruby
# Link dirs files and private-files
set :linked_dirs, fetch(:linked_dirs, []).push('app/sites/default/files', 'private-files')
```

**Note:** This forked version does not use the `linked_files` variable used by the [parent project](https://github.com/unitedworldwrestling/drupal-deploy) to manage the _settings.php_ file for your project. Instead it provides a new command `drupal:sync_settings` to copy the file into position. See the section on **Settings Files** below for more details.

Configure the settings file name for each stage in the `config/deploy/<stage_name>.rb` file in your project. For example, if the settings file for your test environment is `test.settings.php`, add this line:

```ruby
set :settings_file, "test.settings.php"
```

See the section on *Settings Files* at the end of this readme for important info about how to structure your settings files.

Also in the `config/deploy/<stage_name>.rb` file, configure these settings:

```ruby
set :branch, "test"
set :stage, :test
set :settings_file, "test.settings.php"
set :deploy_to, "/var/www/#{fetch(:application)}"
```

For more information about configuration http://capistranorb.com/

## Deployment

### Standard deployment

```
$ cap <stage_name> deploy
```

This command does a standard Capistrano deployment (creates a new release and deletes a previous older release), then invokes the new `sync_settings` task to copy the appropriate settings file.

### Full deployment
```
$ cap <stage_name> deploy:full
```

This invokes the following task sequence:

* Invokes the standard `deploy` task, including `sync_settings`
* Puts the site into maintenance mode
* Runs database updates
* Reverts features (Drupal 7) or imports configuration (Drupal 8)
* Takes the site out of maintenance mode
* Clears the cache

As with any Capistrano project, some preparation is needed on the remote server to configure it in accordance with the structures Capistrano expects. In particular:

* Make sure the path specified in the `deploy_to` setting exists, has the correct permissions, and (for first deployment) is empty. 
* If you are using Apache virtual hosts or Nginx server blocks, you will need to configure the `DocumentRoot` (Apache) or `root` directive to point to the `current` folder within the project folder structure on the remote server.

When you execute the `cap deploy` command, Capistrano will deploy your project to the specified path. Don't despair if it doesn't work at the first attempt. Typical problems that arise are:

* Incorrect `ssh` configuration - make sure you can access the remote server from the command line, e.g. `ssh user@remote`, before running Capistrano commands.
* Make sure your server folder structure exists and is writable by the account you are using over `ssh`.
* Make sure the Git branch you are deploying exists.

If you encounter other problems, please [create an issue](https://github.com/frankhenry/drupal-deploy/issues).

If problems occur after a deployment, you can roll back to the previous release with this command:

```
$ cap <stage-name> deploy:rollback
```

## Available commands

This project adds or modifies the following commands compared to the [parent project](https://github.com/unitedworldwrestling/drupal-deploy):

Command | Description | Status
--------| ----------- | ------
cap drupal:deploy:database_import | Drop the database and import another one | Added
cap drupal:features_revert | Revert all features | Added
cap drupal:sync_settings | Copy the environment-specific settings file | Added
cap drupal:update:pm_updatestatus | Show a report of available minor updates to Drupal core and contrib projects | Added
cap deploy | Deploy a new release | Modified
cap drupal:cache:clear | Clear all caches | Modified
cap drupal:deploy | Deploy a drupal site | Modified
cap drupal:deploy:full | Deploy your project and do an updatedb, configuration import, cache clear | Modified
cap drupal:site_offline | Set the site offline | Modified
cap drupal:site_online | Set the site online | Modified

Use the `cap -T` command to get a full list of available commands.

## Settings Files

The `drupal:sync_settings` task in this repo depends on your settings files being organised in the way described here. If you want to organise your files differently, you will probably need to modify the `sync_settings` task in `drupal_deploy.rake`, or write your own task and invoke it instead of `sync_settings`.

There are lots of ways to manage settings files, but I find it convenient to have one for each environment. Many settings are the same in all environments, so I place those in a shared file which is then included in the environment-specific file, like so:

```php
if (file_exists(__DIR__ . '/shared.settings.php')) {
  include __DIR__ . '/shared.settings.php';
}
```

I use this approach on Drupal 7 and Drupal 8. In the Drupal repo, all settings files are kept in a `settings` folder under the project root. The `sync_settings` task copies the appropriate files during deployment. Typically, the folder structure looks like this:

```
myproject
└───settings
    │   dev.settings.php
    │   local.settings.php
    │   prod.settings.php
    │   shared.settings.php
    │   local.settings.php
```

