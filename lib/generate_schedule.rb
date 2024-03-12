# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'date'

SCHEDULE_FILE = 'lib/schedule.json'
VIEW_FILE = 'index.html'

def pull_pg_schedule(schedule_id:)
  response = get_response(schedule_id: schedule_id)
  mask_results(response[:oncalls][0][:user][:summary])
end

def mask_results(str)
  str.gsub(/.(?=.{4})/, '#')
end

def get_response(schedule_id:)
  uri = URI("https://api.pagerduty.com/oncalls?schedule_ids[]=#{schedule_id}")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Token token=#{ENV['PD_TOKEN']}"
  request['Accept'] = "application/vnd.pagerduty+json;version=2"

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  JSON.parse(response.body, { symbolize_names: true })
end

def insert_schedule(team1:, team2:, team3:)
  data = JSON.parse(File.read(SCHEDULE_FILE))

  new_schedule = {
    "team1": team1,
    "team2": team2,
    "team3": team3,
    "week": Date.today.strftime('%V')
  }

  data << new_schedule
  updated_json_content = JSON.pretty_generate(data)

  save_to_json(updated_json_content)
end

def save_to_json(json_string)
  File.open(SCHEDULE_FILE, 'w') do |f|
    f.write(json_string)
  end
end

def update_og_headers
  json_string = JSON.parse(File.read(SCHEDULE_FILE), { symbolize_names: true })
  html_content = File.read(VIEW_FILE)
  old_meta_tag = '<meta property="og:description" content="Lorem ipsum" />'
  new_meta_tag = "<meta property='og:description' content='New Description #{Date.today.strftime('%V')}'>"
  modified_content = html_content.gsub(old_meta_tag, new_meta_tag)
  File.write(VIEW_FILE, modified_content)
end

user_team1 = pull_pg_schedule(schedule_id: "PGONDG5")
user_team2 = pull_pg_schedule(schedule_id: "P0QYXI3")
user_team3 = pull_pg_schedule(schedule_id: "PWAVTID")

insert_schedule(team1: user_team1, team2: user_team2, team3: user_team3)
update_og_headers