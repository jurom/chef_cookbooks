Chef::Log.info('Starting deploy recipe')

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

  work_dir = '/home/ubuntu'
  zip_name = 'server.zip'
  owner = 'ubuntu'
  group = 'ubuntu'

  s3_bucket, s3_key, base_url = parse_uri(app['app_source']['url'])

  Chef::Log.info("S3 Params: #{s3_bucket}, #{s3_key}, #{base_url}")

  s3_file "#{work_dir}/#{zip_name}" do
    bucket s3_bucket
    remote_path s3_key
    owner owner
    group group
    mode "0755"
    s3_url base_url
    action :create
  end

  Chef::Log.info("Server zip file downloaded")

  execute "unzip server" do
    cwd work_dir
    command "unzip -o #{zip_name}"
  end

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
    variables :work_dir => work_dir, :filename => node[:jar_filename], :config_file => config_path
  end

  service "java_server" do
    supports :restart => true, :start => true, :stop => true, :reload => true
    action [:enable, :reload, :start]
    subscribes :restart, "template[java_server]", :immediately
  end
end
