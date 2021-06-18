# main.rb - The 'main' file of this directory. This file does not contain any logic related to the operation of the staff
# contact feature. All operations related to creating the database tables and setting up the Discord bot and running it, 
# however, are contained here.
require 'sequel'
require 'discordrb'

CAP_ID = 260600155630338048
DB = Sequel.sqlite('data.db')

# Creates tables if they don't already exist

DB.create_table?(:chat_channels) do
  Integer :id, primary_key: true
  Time :creation_time
  Boolean :admin?, default: false
end

DB.create_table?(:chat_users) do
  Integer :id, primary_key: true
  String :distinct
  foreign_key :chat_channel_id, :chat_channels
end

# Opens IRB with access to 'DB' and 'CHAT_SESSIONS' if a '-c' option was provided
if(ARGV[0] == '-c')
  ARGV.clear
  load './console.rb'
  exit(0)
end

require_relative 'config.rb'

module ServerSettings
  # Sets all server, channel and role ID's in the 'server' and 'ban appeal server' hashes as constants of this module
  CONFIG_SETTINGS[:server].each{ |id_name, id| self.const_set(id_name.upcase, id) }
  CONFIG_SETTINGS[:ban_appeal_server].each{ |id_name, id| self.const_set(id_name.upcase, id) }
end

BOT = Discordrb::Commands::CommandBot.new(CONFIG_SETTINGS)

# Includes all command and event handlers from the 'StaffContact' module in the CommandBot instance
Dir['./lib/*.rb'].each{ |file| load file }
BOT.include! StaffContact
BOT.include! Help
# Ban appeals are still a work in progress
# BOT.include! BanAppeals

BOT.ready do 
  BOT.game = "DM me to contact staff"
  puts "Bot started!"
end

BOT.run