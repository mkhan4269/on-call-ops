# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'date'

LOG_ENTRIES_FILE = 'tmp/log_entries.json'
LIMIT = 25
# TODO: Add public holidays logic
# public_holidays_2024 = []

def pull_log_entries(offset: 0)
  response = get_response(offset: offset)
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

def generate_metrics
  data = JSON.parse(File.read(LOG_ENTRIES_FILE), { symbolize_names: true })
  grouped_by_team = data.group_by { |log_entry| log_entry[:teams][0][:summary] }
  teams = grouped_by_team.keys

  metrics = {}
  teams.each do |team|
    grouped_by_incident = grouped_by_team[team].group_by { |log_entry| log_entry[:incident][:incident_number] }
    incidents = determine_work_hours_and_urgency(grouped_by_incident.map { |_k, v| v[0] })
    on_work_hours_low_urgency = incidents.select { |_k, v| v[:in_work_hours] && v[:urgency] == 'low' }
    on_work_hours_high_urgency = incidents.select { |_k, v| v[:in_work_hours] && v[:urgency] == 'high' }
    off_work_hours_low_urgency = incidents.select { |_k, v| !v[:in_work_hours] && v[:urgency] == 'low' }
    off_work_hours_high_urgency = incidents.select { |_k, v| !v[:in_work_hours] && v[:urgency] == 'high' }

    metrics[team] = {
      total_incidents: grouped_by_incident.keys.count,
      incidents_on_work_hours: {
        low_urgency: on_work_hours_low_urgency.count,
        high_urgency: on_work_hours_high_urgency.count
      },
      incidents_off_work_hours: {
        low_urgency: off_work_hours_low_urgency.count,
        high_urgency: off_work_hours_high_urgency.count
      }
    }
  end
  puts metrics
end

def determine_work_hours_and_urgency(log_entries)
  incidents_created_at = {}
  log_entries.map do |entry|
    time = DateTime.parse(entry[:incident][:created_at]) + (2.0 / 24.0)
    incidents_created_at[entry[:incident][:incident_number]] = {
      in_work_hours: on_work_hours?(time) && !in_weekend?(time),
      urgency: entry[:incident][:urgency]
    }
  end
  incidents_created_at
end

def on_work_hours?(time)
  return true if time.hour >= 10 && time.hour < 18

  return true if time.hour == 18 && time.minute <= 30

  false
end

def in_weekend?(time)
  time.saturday? || time.sunday?
end

clear_log_entries
puts 'Pulling log entries'
pull_log_entries
puts 'Generating metrics'
generate_metrics
