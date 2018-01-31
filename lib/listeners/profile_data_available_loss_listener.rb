require 'sneakers'
require 'json'

class ProfileDataAvailableLossListener
  include Sneakers::Worker
  from_queue 'elec.hh.available.loss', routing_key: 'elec.hh.consumption.available'

  def work(message)
    $logger.info 'elec.hh.consumption.available message received now processing loss'
    message_hash = JSON.parse(message)
    date = DateTime.parse(message_hash['date'])
    data = call_loss_calculation_svc(date, message_hash)
    return ack! if data.nil?
    post_to_profile_repo(data, message_hash)
    ack!
  end

  def post_to_profile_repo(data, message_hash)
    response = ProfileDataRepositoryClient.post(message_hash['path'], data)
    if response[:status] != 200
      publish JSON.parse(response[:body]).merge(PassThroughMessageDetails.to_hash(message_hash)).to_json, routing_key: 'elec.hh.loss.post_to_profile.failed'
      $logger.warn "posting to profile repo #{message_hash['path']} failed"
      return
    end
    $logger.warn "posting to profile repo #{message_hash['path']} successful"
    publish JSON.parse(response[:body]).merge(PassThroughMessageDetails.to_hash(message_hash)).to_json, routing_key: 'elec.hh.loss.calculated.successfully'
  end

  def call_loss_calculation_svc(date, message_hash)
    response = LossCalculationServiceClient.post(date, message_hash['distribution_area'].downcase, message_hash['llf_class'], message_hash['data'])

    if response[:status] != 200
      publish response[:body], routing_key: 'elec.hh.loss.calculated.failed'
      $logger.debug "loss calculation failed for #{message_hash['distribution_area'].downcase}>#{message_hash['llf_class']} on #{date}"
      return
    end
    JSON.parse(response[:body])
  end

end