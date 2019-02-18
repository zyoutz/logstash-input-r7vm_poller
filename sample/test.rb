require 'nexpose'

nsc = Nexpose::Connection.new('192.168.86.112','nxadmin','nxpassword', 3780)
nsc.login

# puts nsc.list_sites
#
# report_config = Nexpose::AdhocReportConfig.new(nil, 'sql')
# report_config.add_filter('version', '2.2.0')
# report_config.add_filter('query', 'select * from dim_asset')
#
# report_output = report_config.generate(nsc)
#
# report_output.split("\n").each do |row|
#   puts row
# end

# sites = nsc.list_sites
#
# puts 'Scan ID, Scan Type, Scan Name, Scan Start, Scan End, Scan Duration, Scan Status, Engine Name, Site ID, Site Name'
# nsc.completed_scans(1).each do |scan|
#   puts [scan.id, scan.type, scan.scan_name, scan.start_time, scan.end_time, scan.duration, scan.status, scan.engine_name,
#         scan.site_id, sites.select{|site| site.id == scan.site_id}.first&.name]
#            .join(',')
# end

scan = nsc.completed_scans(1).max_by {|scan| scan.end_time}
puts scan.inspect