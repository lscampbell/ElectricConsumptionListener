require 'sneakers'
require 'json'

class ProfileDataAvailableDuosListener
  include Sneakers::Worker

  from_queue 'elec.hh.available.duos', routing_key: 'elec.hh.consumption.available'

  def work(message)
    $logger.info 'profile.data.consumption.available received processing dous'
    message_hash = JSON.parse(message)

    calculated_duos_data = call_duos_calculation_svc(message_hash)
    return ack! if calculated_duos_data.nil?
    post_duos_to_profile_repo(calculated_duos_data, message_hash)
  end

  def post_duos_to_profile_repo(calculated_duos_data, message_hash)
    response = ProfileDataRepositoryClient.post("#{message_hash['path']}/duos", calculated_duos_data)
    if response[:status] != 200
      publish JSON.parse(response[:body]).merge(PassThroughMessageDetails.to_hash(message_hash)).to_json, routing_key: 'elec.hh.duos.post_to_profile.failed'
      $logger.debug "posting to profile repo #{message_hash['path']} failed"
      return ack!
    end
    $logger.debug "posting to profile repo #{message_hash['path']} successful"
    publish JSON.parse(response[:body]).merge(PassThroughMessageDetails.to_hash(message_hash)).to_json, routing_key: 'elec.hh.duos.calculated.successfully'
    ack!
  end

  def call_duos_calculation_svc(message_hash)
    response = DuosCalculationServiceClient.post(message_hash['distribution_area'].downcase, message_hash['llf_class'], message_hash['data'])
    if response[:status] != 200
      $logger.info 'posting to duos service failed'
      publish response[:body], routing_key: 'elec.hh.duos.calculation.failed'
      return
    end
    JSON.parse(response[:body])
  end
end