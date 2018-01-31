require 'rest-client'
require 'json'

class ProfileDataRepositoryClient

  def self.base_url
    ENV['ELEC_PROFILE_REPO_URL'] || 'http://elec_profile:4581'
  end

  def self.post(path, data)
    url = "#{base_url}#{path}"
    $logger.info "posting data to: #{url}"
    $statsd.time('listeners.post.to.profile.repo') do
      RestClient.post(url, data.to_json, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end

  def self.get(path)
    url = "#{base_url}#{path}"
    $logger.info "getting data from: #{url}"
    $statsd.time('listeners.get.from.profile.repo') do
      RestClient.get(url, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end

end