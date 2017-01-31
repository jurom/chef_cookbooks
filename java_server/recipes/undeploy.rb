service "java_server" do
  action :stop
  provider Chef::Provider::Service::Upstart
end

file "java_server" do
  path "/etc/init/java_server.conf"
  action :delete
end
