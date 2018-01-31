class ChargeServiceClient
  def self.base_url
    ENV['CHARGE_SERVICE_URL'] || 'http://charge:4583'
  end

  def self.post(customer, supply_point_reference, date, supply_point_day, supply_point_info)
    url = "#{base_url}/#{customer}/supply-points/#{supply_point_reference}/charges/#{date.strftime('%F')}"
    $logger.info "posting data to #{url}"
    $statsd.time('listeners.post.charges') do
      RestClient.post(url, {profile_data: supply_point_day, supply_point_info: supply_point_info}.to_json, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end
end