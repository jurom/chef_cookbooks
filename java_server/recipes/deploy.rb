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

  current_dir = ::File.join(deploy[:deploy_to], 'current')

  Chef::Log.info("Current dir: #{current_dir}")

  service "java_server" do
    supports :status => true
    action :stop
  end

  template "java_server" do
    path "/etc/init/java_server.conf"
    source "java_service.erb"
    owner deploy[:user]
    group deploy[:group]
    mode "0755"
    variables :work_dir => current_dir, :filename => node[:jar_filename]
  end

  service "java_server" do
    supports :restart => true, :start => true, :stop => true, :reload => true
    action [:enable, :start]
    provider Chef::Provider::Service::Upstart
    subscribes :restart, "template[java_server]", :immediately
  end

end
