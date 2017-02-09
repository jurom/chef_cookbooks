Chef::Log.info('Starting deploy transactor recipe')

owner = 'ubuntu'
group = 'ubuntu'
work_dir = ::File.join("/home", owner)
# This will be the name of the downloaded zip
zip_file = 'datomic.zip'
zip_file_path = ::File.join(work_dir, zip_file)

services_path = "/lib/systemd/system"
transactor_service = 'transactor.service'
transactor_service_path = ::File.join(services_path, transactor_service)

search("aws_opsworks_app").each do |app|
  app_name = app['shortname']

  # By default, all apps are deployed to all layers. We want to avoid this as we have a different app for each layer
  if node.key?(:single_app) && node[:single_app] != app_name
    Chef::Log.info("Skipping deploy of #{app_name} as the single_app is specified to #{node[:single_app]}")
    next
  end

  Chef::Log.info("App #{app_name} source: #{app['app_source']['url']}")

  service transactor_service do
    supports :status => true
    action :stop
    only_if { File.exist?(transactor_service_path) }
  end

  s3_download zip_file_path do
    url app['app_source']['url']
  end

  Chef::Log.info("Datomic zip file downloaded")

  execute "unzip -o #{zip_file_path} -d #{work_dir}"
  # TODO(jurom): Maybe it would be better not to download datomic once it's already downloaded.
  # Also, we'll need to add an override flag in cusom JSON for the case we wanted to change the datomic inside.
  execute "rm #{zip_file_path}"

  # Assume that there's a directory called datomic inside the extracted zip
  transactor_dir = ::File.join(work_dir, 'datomic')

  # Transactor needs a config to work with - this will be created from template
  config_path = ::File.join(work_dir, 'transactor_config.properties')

  Chef::Log.info("Creating transactor config template")

  template "transactor_config" do
    path config_path
    source "transactor_config.erb"
    owner owner
    group group
    mode "0644"
    variables config: {
      host: search("aws_opsworks_instance", "self:true").first[:private_ip],
      table: node[:datomic][:table],
      license_key: node[:datomic][:license_key]
    }
  end

  # Create a transactor service (if not already created)
  template "transactor_template" do
    path transactor_service_path
    source "transactor_service.erb"
    owner owner
    group group
    mode "0755"
    variables :work_dir => work_dir, :transactor_dir => transactor_dir, :transactor_config => config_path
  end

  execute "systemctl daemon-reload"

  service transactor_service do
    supports :restart => true, :start => true, :stop => true
    action [:enable, :start]
  end
end
