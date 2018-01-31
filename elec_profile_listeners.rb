require 'logger'
require 'sneakers'
require 'datadog/statsd'
require 'active_support/core_ext/hash/indifferent_access'

host = ENV['STATSD_HOST'] || 'dd-agent'
$statsd = Datadog::Statsd.new host

RABBIT_HOST = ENV['RABBIT_HOST'] || 'rabbitmq'

Dir["#{File.dirname(__FILE__)}/lib/**/*.rb"].each { |f| require(f) }

$logger = Logger.new(STDOUT)
$logger.level = ENV['LOG_ENV'].nil? ? Logger::ERROR : ENV['LOG_ENV'].to_i
$logger.info "using rabbit mq host - #{RABBIT_HOST}"
rabbit_user = ENV['RABBIT_USER']
rabbit_password = ENV['RABBIT_PASSWORD']

$logger.info("using rabbit login #{rabbit_user}")

Sneakers.configure heartbeat: 2,
                   amqp: "amqp://#{rabbit_user}:#{rabbit_password}@#{RABBIT_HOST}:5672",
                   durable: false,
                   vhost: '/',
                   exchange: 'elec-profile-data',
                   exchange_type: :topic,
                   prefetch: 1,
                   timeout_job_after: 5,
                   workers: 8

Sneakers.logger.level = ENV['SNEAKERS_ENV'].nil? ? Logger::FATAL : ENV['SNEAKERS_ENV'].to_i