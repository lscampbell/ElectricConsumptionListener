require 'rest-client'
require 'json'
class LossCalculationServiceClient
  def self.base_url
    ENV['LOSS_SERVICE_URL'] || 'http://loss:4580'
  end

  def self.post(date, area, llf_class, data)
    url = "#{base_url}/calculateloss/#{area}/#{llf_class}/#{date}"
    $logger.info "posting data to #{url}"
    $statsd.time('listeners.post.calculate.loss') do
      RestClient.post(url, {data: data}.to_json, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end
end