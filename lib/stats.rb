require 'datadog/statsd'
class Stats
  def self.client
    @@client ||= Datadog::Statsd.new
  end
end