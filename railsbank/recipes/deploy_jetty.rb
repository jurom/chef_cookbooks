Chef::Log.info('Starting deploy jetty recipe')

owner = 'ubuntu'
group = 'ubuntu'
work_dir = ::File.join("/home", owner)
jar_filename = node.key?(:jar_filename) ? node[:jar_filename] : 'railsbank-server.jar'
jar_path = ::File.join(work_dir, jar_filename)
jetty_service = 'railsbank.service'
jetty_service_path = ::File.join("/lib/systemd/system/", jetty_service)
config_path = ::File.join(work_dir, 'config')

search("aws_opsworks_app").each do |app|
  app_name = app['shortname']

  # By default, all apps are deployed to all layers. We want to avoid this as we have a different app for each layer
  if node.key?(:single_app) && node[:single_app] != app_name
    Chef::Log.info("Skipping deploy of #{app_name} as the single_app is specified to #{node[:single_app]}")
    next
  end

  Chef::Log.info("App #{app_name} source: #{app['app_source']['url']}")

  service jetty_service do
    supports :status => true
    action :stop
    only_if { File.exist?(jetty_service_path) }
  end

  # Assume there's a JAR on the url
  s3_download jar_path do
    url app['app_source']['url']
  end

  Chef::Log.info("Server jar file downloaded")

  # Write the env var provided from the App definition to a config file
  env_vars = app['environment'].map{|name, value| "#{name}=#{value}"}.join("\n")

  file "config_file" do
    path config_path
    content env_vars
  end

  template "java_server_template" do
    path jetty_service_path
    source "java_service.erb"
    owner owner
    group group
    mode "0755"
    variables :work_dir => work_dir, :jar_path => jar_path, :config_path => config_path
  end

  execute "systemctl daemon-reload"

  service jetty_service do
    supports :restart => true, :start => true, :stop => true
    action [:enable, :start]
  end
end
