class ElecSupplyPointsServiceClient
  def self.base_url
    ENV['ELEC_SUPPLY_POINTS_SERVICE_URL'] || 'http://elec_supply_points:4584'
  end

  def self.get(mpan, date)
    url = "#{base_url}/supply-points/#{mpan}/#{date.strftime('%F')}"
    $logger.info "getting data from #{url}"
    $statsd.time('listeners.get.supply.point.details') do
      RestClient.get(url, {content_type: :json, accept: :json}) do |resp, req, result|
        {status: resp.code, body: resp.body}
      end
    end
  end
end
