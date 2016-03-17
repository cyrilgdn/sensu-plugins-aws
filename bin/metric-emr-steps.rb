#! /usr/bin/env ruby
#
# metric-emr-steps
#
# DESCRIPTION:
#   Lists steps in EMR cluster queue with their status.
#
# OUTPUT:
#   plain-text
#
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Bryan Absher <bryan.absher@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugins-aws'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class EC2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.emr'

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :cluster_name,
        short: '-b CLUSTER_NAME',
        long: '--cluster-name',
        description: 'The name of the EMR cluster',
        required: true

  def count(steps, status)
    count = steps.count {|step| step.status.state == status }
  end

  STATUS = ["PENDING", "RUNNING", "COMPLETED","CANCELLED", "FAILED", "INTERRUPTED"]

  def cluster_steps(emr, cluster_id, data)
    steps = emr.list_steps({
        cluster_id: cluster_id
      }).steps
    STATUS.each_entry {|s| data[s] += count(steps, s)}
  end

  def run
    emr = Aws::EMR::Client.new(aws_config)
    begin
      emr_clusters = emr.list_clusters().clusters
      clusters = emr_clusters.select { |c| c.name == config[:cluster_name] }
      critical "EMR cluster #{config[:cluster_name]} not found" if clusters.empty?
      cluster = clusters.sort_by{|c| c.status().timeline.creation_date_time}.reverse.first
      data = {}
      STATUS.each_entry{|status| data[status] = 0}
      cluster_steps(emr, cluster.id, data)
      safeName = config[:cluster_name].gsub(" ", "_")
      STATUS.each_entry{|status| output config[:scheme] + "." + safeName + ".step." + status, data[status] }
    end
    ok
  end
end
