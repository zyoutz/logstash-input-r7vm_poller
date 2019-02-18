# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname

require 'nexpose'
require 'rufus/scheduler'
require 'yaml'

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::R7vmPoller < LogStash::Inputs::Base
  config_name "r7vm_poller"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  config :last_run_path, :validate => :string, :default => "#{ENV['HOME']}/.logstash_r7vm_last_run"

  # The message string to use in the event.
  config :message, :validate => :string, :default => "Hello World!"

  config :interval, :validate => :number, :obsolete => "The interval options is obsolete. Use schedule instead"

  config :console, :validate => :hash, :required => true

  config :query, :validate => :hash, :required => true

  config :schedule, :validate => :string

  # Define the target field for placing the received data. If this setting is omitted, the data will be stored at the root (top level) of the event.
  config :target, :validate => :string

  public
  Schedule_types = %w(cron every at in)
  def register
    @host = Socket.gethostname

    @logger.info("Registering r7vm_poller Input", :type => @type, :schedule => @schedule, :console => @console)

    setup_connection!
  end # def register

  private
  def setup_connection!
    @nsc = Nexpose::Connection.new(@console['host'],@console['user'],@console['pass'],@console['port'])
    @nsc.login

    at_exit do
      @nsc.logout
    end
  end

  public
  def run(queue)
    if @schedule
      @scheduler = Rufus::Scheduler.new(:max_work_threads => 1)
      @scheduler.cron @schedule do
        @logger.info("Running query now...")
        execute_extract(queue)
      end

      @scheduler.join
    else
      execute_extract(queue)
    end
  end # def run

  private
  def execute_extract(queue)
    site_ids = @query['sites'].empty? ? @nsc.list_sites.map{|site|site.id} : @query['sites']

    site_ids.each do |site_id|
      # Check if scan has been processed yet
      # last_run_path
      if File.exists?(@last_run_path)
        @last_run_data = YAML.load(File.read(@last_run_path))
      else
        @last_run_data = Hash.new
      end

      # Get Scan Details
      scan_details = get_last_scan_details(site_id)

      if @last_run_data[site_id].nil? || @last_run_data[site_id] < scan_details[:id]
        @logger.info("Processing Scan #{scan_details[:id]} for Site #{site_id}...")
        # Get Devices for Scan
        device_details = execute_query(@query['sql_devices'], site_id)
        @logger.info("#{device_details.length} devices to be processed")

        device_details.each do |row|
          # @logger.info("Process device row...")
          event = LogStash::Event.new({'device_data' => row})
          decorate(event)
          queue << event
        end

        # Get Findings for Site of Scan
        finding_details = execute_query(@query['sql_findings'], site_id)
        @logger.info("#{finding_details.length} findings to be processed")

        finding_details.each do |row|
          event = LogStash::Event.new({'finding_data' => row})
          decorate(event)
          queue << event
        end

        # Save scan details
        scan_event = LogStash::Event.new(scan_details)
        decorate(scan_event)
        queue << scan_event

        # Update state file
        @last_run_data[site_id] = scan_details[:id]
        update_state_file
      else
        @logger.info("Scan #{scan_details[:id]} has already been processed for Site #{site_id}, skipping...")
      end
    end
  end

  private
  def get_last_scan_details(site_id)
    sites = @nsc.list_sites

    scan = @nsc.completed_scans(site_id).max_by {|scan| scan.end_time}

    {
        id: scan.id,
        type: scan.type,
        name: scan.scan_name,
        start_time: scan.start_time,
        end_time: scan.end_time,
        duration: scan.duration,
        status: scan.status,
        engine_name: scan.engine_name,
        site: {
            id: scan.site_id,
            name: sites.select{|site| site.id == scan.site_id}.first&.name
        }
    }
  end

  private
  def execute_query(query, site_id)
    report_config = Nexpose::AdhocReportConfig.new(nil, 'sql')
    report_config.add_filter('version', @query['rdm_version'])
    report_config.add_filter('query', query)
    report_config.add_filter('site', site_id)

    report_output = report_config.generate(@nsc)
    return report_output.split("\n")
  end

  private
  def update_state_file
    File.write(@last_run_path, YAML.dump(@last_run_data))
  end

  public
  def stop
    # nothing to do in this case so it is not necessary to define stop
    # examples of common "stop" tasks:
    #  * close sockets (unblocking blocking reads/accepts)
    #  * cleanup temporary files
    #  * terminate spawned threads
  end
end # class LogStash::Inputs::R7vmPoller
