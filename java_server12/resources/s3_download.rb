resource_name :s3_download

property :path, String, name_property: true
property :url, String, required: true
property :owner, String, default: 'ubuntu'
property :group, String, default: 'ubuntu'
property :mode, String, default: '0755'

default_action :download

action :download do
  s3_bucket, s3_key, base_url = JavaServer::S3::parse_uri(url)

  Chef::Log.info("S3 Params: #{s3_bucket}, #{s3_key}, #{base_url}")

  s3_file path do
    bucket s3_bucket
    remote_path s3_key
    s3_url base_url
    owner owner
    group group
    mode mode
    action :create
  end
end
