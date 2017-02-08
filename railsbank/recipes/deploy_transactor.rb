Chef::Log.info('Starting deploy transactor recipe')

owner = 'ubuntu'
group = 'ubuntu'
work_dir = "/home/#{owner}"
zip_file = 'datomic.zip'

search("aws_opsworks_app").each do |app|
  app_name = app['shortname']

  if node.key?(:single_app) && node[:single_app] != app_name
    Chef::Log.info("Skipping deploy of #{app_name} as the single_app is specified to #{node[:single_app]}")
    next
  end

  Chef::Log.info("App #{app_name} source: #{app['app_source']['url']}")

  service "transactor" do
    supports :status => true
    action :stop
  end

  s3_download "#{work_dir}/#{zip_file}" do
    url app['app_source']['url']
  end

  Chef::Log.info("Datomic zip file downloaded")

  execute "unzip -o #{zip_file}"
  execute "rm #{zip_file}"

  # Assume that there's a directory called datomic inside
  transactor_dir = ::File.join(work_dir, 'datomic')

  config_path = ::File.join(work_dir, 'transactor_config.properties')

  Chef::Log.info("Creating transactor config template")

  template "transactor_config" do
    path config_path
    source "transactor_config.erb"
    owner owner
    group group
    mode "0755"
    variables config: {
      :host => search("aws_opsworks_instance").first[:private_ip],
      :table => node[:datomic][:table],
      :license_key => node[:datomic][:license_key]
    }
  end

  template "transactor" do
    path "/lib/systemd/system/transactor.service"
    source "transactor_service.erb"
    owner owner
    group group
    mode "0755"
    variables :work_dir => work_dir, transactor_dir => transactor_dir, :transactor_config => config_path
  end

  execute "systemctl daemon-reload"

  service "java_server" do
    supports :restart => true, :start => true, :stop => true
    action [:enable, :start]
    subscribes :restart, "template[java_server]", :immediately
  end
end
