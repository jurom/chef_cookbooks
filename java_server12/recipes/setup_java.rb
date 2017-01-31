apt_update 'all platforms' do
  action :periodic
  frequency 86_400
end

apt_package 'default-jre'

apt_package 'unzip'
