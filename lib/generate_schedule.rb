# frozen_string_literal: true

require 'json'
SCHEDULE_FILE = 'schedule.json'

def pull_pg_schedule
  file_content = JSON.parse(File.read('pg_response.json'))
  file_content['oncalls'][0]['user']['summary']
end

def insert_schedule(team1:, team2:, team3:)
  file_content = File.read(SCHEDULE_FILE)
  data = JSON.parse(file_content)
  current_week = data[data.size - 1]['week'] + 1

  new_schedule = {
    "team1": team1,
    "team2": team2,
    "team3": 'Emily Johnson',
    "week": current_week
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

user_team1 = pull_pg_schedule
user_team2 = pull_pg_schedule
user_team3 = pull_pg_schedule

insert_schedule(team1: user_team1, team2: user_team2, team3: user_team3)
