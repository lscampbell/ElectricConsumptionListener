class SupplyPointMetaFinder
  include Sneakers::Worker
  from_queue 'elec.profile.ingress'

  def work(message)
    msg_hash = JSON.parse(message).deep_symbolize_keys
    response = ElecSupplyPointsServiceClient.get(msg_hash[:mpan], DateTime.parse(msg_hash[:date]))

    if response[:status] == 200
      supply_point_response = JSON.parse(response[:body]).deep_symbolize_keys
      $logger.info "response from supply points service - #{supply_point_response}"
      supply_point_response[:customers].each do |cust|
        publish_message_for(msg_hash, supply_point_response, cust)
      end
    else
      $logger.info "retrieving data from supply point service for #{msg_hash[:mpan]}/#{msg_hash[:date]} failed "
      return ack!
    end
    ack!
  end

  def publish_message_for(msg_hash, supply_point_response, customer)
    update_hash = msg_hash.merge(
      customer:               customer[:customer],
      mpan_top_row:           supply_point_response[:mpan_top_row],
      supply_point_reference: supply_point_response[:supply_point_reference],
      distribution_area:      supply_point_response[:distribution_area],
      llf_class:              supply_point_response[:llf_class],
      bands:                  customer[:bands],
      supply_capacity:        supply_point_response[:supply_capacity]
    )
    routing_key = supply_point_response[:half_hourly] ? 'elec.hh.consumption.imported' : 'profile.non.half.hourly.data.consumption.available'

    publish update_hash.reject { |k, v| k == :mpan }.to_json, routing_key: routing_key
  end
end