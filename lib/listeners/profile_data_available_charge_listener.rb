require 'json'
require 'sneakers'


class ProfileDataAvailableChargeListener
  include Sneakers::Worker

  from_queue 'elec.hh.available.calc.charges', routing_key: 'elec.hh.*.calculated.successfully'

  def work(message)
    $logger.info 'profile.data.*.calculated.successfully message received - processing charges'
    msg_hash = JSON.parse(message)

    supply_point_day = retrieve_profile_data(msg_hash)
    return ack! if supply_point_day.nil?
    $logger.debug 'about to calc charges'

    return calculate_charges(msg_hash, supply_point_day)
  end

  def calculate_charges(msg_hash, supply_point_day)
    supp_point_info = extract_supp_point_info(msg_hash)
    return ack! if supp_point_info.nil?
    start = Time.now
    response = ChargeServiceClient.post(msg_hash['customer'], msg_hash['supply_point_reference'], DateTime.parse(msg_hash['date']), supply_point_day, supp_point_info)
    if response[:status] == 200
      publish(parse_json_or_error(response[:body]).merge(PassThroughMessageDetails.to_hash(msg_hash)).to_json,
              routing_key: 'elec.hh.charges.calculated.successfully')
      $logger.debug "posting to charge service for #{msg_hash['supply_point_reference']} on #{msg_hash['date']} succeeded in #{'%.08f' % (Time.now - start)} secs"
    else
      $logger.info "posting to charge service failed for #{msg_hash['supply_point_reference']} on #{msg_hash['date']}"
      publish(parse_json_or_error(response[:body]).merge(PassThroughMessageDetails.to_hash(msg_hash)).to_json,
              routing_key: 'elec.hh.charges.calculated.failed')
    end
    ack!
  end

  def retrieve_profile_data(msg_hash)
    url = msg_hash['path']
    $logger.info "retrieving data from #{url}"
    start = Time.now
    response = ProfileDataRepositoryClient.get(url)
    $logger.debug("profile data retrieved in #{'%.08f' % (Time.now - start)} secs")
    if response[:status] != 200
      publish response[:body], routing_key: 'elec.hh.data.charges.profile.retrieval.failed'
      return
    end
    $logger.debug 'response received about to parse'
    JSON.parse(response[:body])
  end

  def extract_supp_point_info(msg_hash)
    {
        bands: msg_hash['bands'],
        supply_capacity: msg_hash['supply_capacity']
    }
  end

  def parse_bands(msg_hash, charge_bands)
    $logger.debug "retrieving supply point data for #{msg_hash['supply_point_reference']} on #{msg_hash['date']} succeeded\nretrieved these ..."
    $logger.debug charge_bands
    charge_bands
  end

  def no_bands_found(msg_hash)
    $logger.info("supply point data missing for supply point '#{msg_hash['supply_point_reference']}' on '#{msg_hash['date']}'")
    publish({
                supply_point_reference: msg_hash['supply_point_reference'],
                date: msg_hash['date'],
                routing_key: 'charge.calculation.bands.missing'
            }.to_json, routing_key: 'charge.calculation.bands.missing')
    {bands:[]}
  end

  def parse_json_or_error(body)
    begin
      JSON.parse(body)
    rescue
      {error: body}
    end
  end


end