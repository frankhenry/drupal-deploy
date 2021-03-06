# Load default values the capistrano 3.x way.
# See https://github.com/capistrano/capistrano/pull/605

namespace :load do
  task :defaults do
    set :app_path, 'app'
  end
end

# Specific Drupal tasks
namespace :drupal do

    desc "Deploy a drupal site" 
    task :deploy do
      invoke "deploy"
      invoke "drupal:sync_settings"
    end
    task default: :deploy

    namespace :deploy do
      
      desc "Deploy your project and do an updatedb, configuration import, cache clear..."
      task :full do
        invoke "drupal:deploy"
        invoke "drupal:site_offline"
        invoke "drupal:update:updatedb"
        if fetch(:drupal_version) == '7' then
          invoke "drupal:features_revert"
        else
          invoke "drupal:configuration_import"
        end  
        invoke "drupal:site_online"
      end

      desc "Drop the database and import another one"
      task :database_import do
        ask(:database_file, "Path to database file you want to import")
        db = fetch(:database_file)
        on roles(:app) do
          if test("[ -f #{db} ]")
            within release_path.join(fetch(:app_path)) do
              execute :drush, "sql-cli < #{db}"
            end  
          else 
            puts "Cannot import the database because file #{db} does not exist on the remote server"
          end  
        end    
      end
  end

  desc 'Run any drush command'
  task :drush do
    ask(:drush_command, "Drush command you want to run (eg. 'cache-clear css-js'). Type 'help' to have a list of avaible drush commands.")
    command = fetch(:drush_command)
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, command
      end
    end
  end

  desc 'Show logs'
  task :logs do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'watchdog-show  --tail'
      end
    end
  end

  desc 'Provides information about things that may be wrong in your Drupal installation, if any.'
  task :requirements do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'core-requirements'
      end
    end
  end

  desc 'Open an interactive shell on a Drupal site.'
  task :cli do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'core-cli'
      end
    end
  end

  desc 'Set the site offline'
  task :site_offline do
    on roles(:app) do
      if fetch(:drupal_version) == '7' then
        command = 'vset maintenance_mode 1'
      else
        command = 'state-set system.maintenance_mode 1 -y'
      end
      within release_path.join(fetch(:app_path)) do
        execute :drush, "#{command}"
      end
    end
  end

  desc 'Set the site online'
  task :site_online do
    on roles(:app) do
      if fetch(:drupal_version) == '7' then
        command = 'vset maintenance_mode 0'
      else
        command = 'state-set system.maintenance_mode 0 -y'
      end
      within release_path.join(fetch(:app_path)) do
        execute :drush, "#{command}"
      end
    end
  end

  desc 'Import configuration'
  task :configuration_import do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'config-import -y'
      end
    end
  end

  desc 'Revert all features'
  task :features_revert do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'fra -y'
      end
    end
  end

  desc 'Backup the database using backup and migrate'
  task :backupdb do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'bam-backup'
      end
    end
  end

  desc 'Copy the environment-specific settings file'
  task :sync_settings do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
          settings_src = "#{release_path}/settings/#{(fetch(:settings_file))}"
          settings_dest = "#{release_path}/#{(fetch(:app_path))}/sites/default/settings.php"
          execute :cp, "#{settings_src} #{settings_dest}"        
          settings_shared_src = "#{release_path}/settings/shared.settings.php}"
          if test("[ -f #{settings_shared_src} ]") do
              settings_shared_dest = "#{release_path}/#{(fetch(:app_path))}/sites/default/shared.settings.php"
              execute :cp, "#{settings_src} #{settings_dest}"            
            end  
          else 
            puts "No shared.settings.php file in this project"
          end          
      end
    end
  end      

  namespace :update do
    desc 'List any pending database updates.'
    task :updatedb_status do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'updatedb-status'
        end
      end
    end

    desc 'Apply any database updates required (as with running update.php).'
    task :updatedb do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'updatedb -y'
        end
      end
    end

    desc 'Show a report of available minor updates to Drupal core and contrib projects.'
    task :pm_updatestatus do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          if fetch(:drupal_version) == '7' then
            execute :drush, 'pm-updatestatus'
          else
            puts "This command only works on Drupal 7"
          end
        end
      end
    end
  end

  namespace :cache do
    desc 'Clear all caches'
    task :clear do
      on roles(:app) do
        if fetch(:drupal_version) == '7' then
          command = 'cache-clear all'
        else
          command = 'cache-rebuild'
        end
        within release_path.join(fetch(:app_path)) do
          execute :drush, "#{command}"
        end
      end
    end
  end

end

namespace :files do

  desc "Download drupal sites files (from remote to local)"
  task :download do
    run_locally do 
      on release_roles :app do |server|
        ask(:answer, "Do you really want to download the files on the server to your local files? Nothing will be deleted but some files might be ovewritten. (y/N)");
        if fetch(:answer) == 'y' then
          remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/"
          local_files_dir = "#{(fetch(:app_path))}/sites/default/files/"
          system("rsync --recursive --times --rsh=ssh --human-readable --progress --exclude='.*' --exclude='css' --exclude='js' #{server.user}@#{server.hostname}:#{remote_files_dir} #{local_files_dir}")
        end
      end
    end
  end

  desc "Upload drupal sites files (from local to remote)"
  task :upload do
    on release_roles :app do |server|
      ask(:answer, "Do you really want to upload your local files to the server? Nothing will be deleted but files can be overwritten. (y/N)");
      if fetch(:answer) == 'y' then
        remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/"
        local_files_dir = "#{(fetch(:app_path))}/sites/default/files/"
        system("rsync --recursive --times --rsh=ssh --human-readable --progress --exclude='.*' --exclude='css' --exclude='js' #{local_files_dir} #{server.user}@#{server.hostname}:#{remote_files_dir}")
      end
    end
  end

  desc "Fix drupal upload files folder permission"
  task :fix_permission do
    on roles(:app) do
      remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/*"
      execute :chgrp, "-R www-data #{remote_files_dir}"
      execute :chmod, "-R g+w #{remote_files_dir}"
    end
  end

end

# namespace :theme do

#   desc "Install dependencies and build theme"
#   task :build do
#     on roles(:app) do |server|
#       system("sh ./scripts/deploy/build-theme.sh")
#     end
#   end

# end
