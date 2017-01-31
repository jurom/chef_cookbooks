Chef::Log.info('Starting deploy recipe')

node[:deploy].each do |application, deploy|

  if node.key?(:single_app) && node[:single_app] != application
    Chef::Log.info("Skipping deploy of #{application} as the single_app is specified to #{node[:single_app]}")
    next
  end

  Chef::Log.info("Current deploy attr: #{application} #{deploy}")

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  # current_dir = ::File.join(deploy[:deploy_to], 'current')

  template_path = ::File.join(current, 'transactor_config.properties')

  Chef::Log.info("Creating transactor config template")

  template "transactor_config" do
    path template_path
    source "transactor_config.erb"
    owner deploy[:user]
    group deploy[:group]
    mode "0755"
    variables config: {
      :host => node[:opsworks][:instance][:private_ip],
      :table => node[:datomic][:table],
      :license_key => node[:datomic][:license_key]
    }
  end

  service "transactor" do
    supports :status => true
    action :stop
  end



  service "java_server" do
    supports :restart => true, :start => true, :stop => true, :reload => true
    action [:enable, :start]
    provider Chef::Provider::Service::Upstart
    subscribes :restart, "template[java_server]", :immediately
  end

end
