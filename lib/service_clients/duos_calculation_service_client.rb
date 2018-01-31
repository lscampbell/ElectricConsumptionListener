require 'rest-client'
require 'json'
class DuosCalculationServiceClient
  def self.base_url
    ENV['DUOS_SERVICE_URL'] || 'http://duos:4578'
  end

  def self.post(area, llf_class, data)
    url = "#{base_url}/calculateduos/#{area.downcase}/#{llf_class}"
    $logger.info "posting data to #{url}"
    $statsd.time('listeners.post.calculate.duos') do
      RestClient.post(url, {data: data}.to_json, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end
end