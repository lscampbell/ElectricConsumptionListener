require 'sneakers'
require 'json'

class ProfileImportListener
  include Sneakers::Worker
  from_queue 'elec.hh.consumption.imported'

  def work(message)
    request = JSON.parse(message)
    post_profile_data(request)
    ack!
  end

  def post_profile_data(request)
    path = ProfileDataPathBuilder.build(request['customer'], request['supply_point_reference'], DateTime.parse(request['date']))
    response = ProfileDataRepositoryClient.post path, {data: request['data']}
    unless response[:status] == 200
      $logger.info "posting profile data to #{path} failed"
      publish(response[:body], routing_key: 'profile.data.consumption.import.save.failed')
      return
    end
    $logger.info "posting profile data to #{path} successful"
    publish_success_message(request, JSON.parse(response[:body]))
  end

  def publish_success_message(request, response_hash)
    message_body = response_hash.merge(PassThroughMessageDetails.to_hash(request)).to_json
    publish(message_body, routing_key: 'elec.hh.consumption.available')
    $logger.info "processing half hourly data for #{request['supply_point_reference']} on #{request['date']}"
    return
  end
end
