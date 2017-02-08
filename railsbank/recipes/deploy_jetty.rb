Chef::Log.info('Starting deploy jetty recipe')

jar_filename = node.key?(:jar_filename) ? node[:jar_filename] : 'railsbank-server.jar'
owner = 'ubuntu'
group = 'ubuntu'
work_dir = "/home/#{owner}"

search("aws_opsworks_app").each do |app|
  app_name = app['shortname']

  if node.key?(:single_app) && node[:single_app] != app_name
    Chef::Log.info("Skipping deploy of #{app_name} as the single_app is specified to #{node[:single_app]}")
    next
  end

  Chef::Log.info("App #{app_name} source: #{app['app_source']['url']}")

  service "java_server" do
    supports :status => true
    action :stop
  end

  s3_download "#{work_dir}/#{jar_filename}" do
    url app['app_source']['url']
  end

  Chef::Log.info("Server jar file downloaded")

  env_vars = app['environment'].map{|name, value| "#{name}=#{value}"}.join("\n")

  config_path = ::File.join(work_dir, 'config')

  file "config_file" do
    path config_path
    content env_vars
  end

  template "java_server" do
    path "/lib/systemd/system/java_server.service"
    source "java_service.erb"
    owner owner
    group group
    mode "0755"
    variables :work_dir => work_dir, :filename => jar_filename, :config_file => config_path
  end

  execute "systemctl daemon-reload"

  service "java_server" do
    supports :restart => true, :start => true, :stop => true
    action [:enable, :start]
    subscribes :restart, "template[java_server]", :immediately
  end
end
