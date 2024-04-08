# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'date'

LOG_ENTRIES_FILE = 'tmp/log_entries.json'
LIMIT = 25

def pull_log_entries(offset: 0)
  response = get_response(offset: offset)
  puts response[:more]
  insert_log_entries(log_entries: response[:log_entries])

  return unless response[:more] == true

  pull_log_entries(offset: response[:limit] + response[:offset])
end

def get_response(offset: 0)
  teams_ids = ['P4G8TAV', 'PX5Y95N', 'P71QVSL']
  teams_param = teams_ids.map { |x| "team_ids[]=#{x}" }.join('&')
  since = "#{Date.today - 14}T00:00:00Z"
  until_today = "#{Date.today}T00:00:00Z"
  uri = URI("https://api.pagerduty.com/log_entries?#{teams_param}&since=#{since}&until=#{until_today}&include[]=incidents&limit=#{LIMIT}&offset=#{offset}")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Token token=#{ENV['PD_TOKEN']}"
  request['Accept'] = 'application/vnd.pagerduty+json;version=2'

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  JSON.parse(response.body, { symbolize_names: true })
end

def insert_log_entries(log_entries:)
  data = JSON.parse(File.read(LOG_ENTRIES_FILE))
  data << log_entries
  updated_json_content = JSON.pretty_generate(data.flatten)

  save_to_json(updated_json_content)
end

def save_to_json(json_string)
  File.open(LOG_ENTRIES_FILE, 'w') do |f|
    f.write(json_string)
  end
end

# TODO: Remove redundant method
def clear_log_entries
  File.open(LOG_ENTRIES_FILE, 'w') do |f|
    f.write([])
  end
end

clear_log_entries
pull_log_entries
