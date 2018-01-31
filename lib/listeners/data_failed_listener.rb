class DataFailedListener
  include Sneakers::Worker

  from_queue 'data.failed', routing_key: %w(#.failed #.missing)

  def work(message)
    $logger.info message
    ack!
  end
end