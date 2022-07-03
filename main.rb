# main.rb - The 'main' file of this directory. This file does not contain any logic related to the operation of the staff
# contact feature. All operations related to creating the database tables and setting up the Discord bot and running it, 
# however, are contained here.
require 'discordrb'
require_relative 'db/db_init'
require_relative 'config.rb'

CAP_ID = 260600155630338048

module ServerSettings
  # Sets all server, channel and role ID's in the 'server' and 'ban appeal server' hashes as constants of this module
  CONFIG_SETTINGS[:server].each{ |id_name, id| self.const_set(id_name.upcase, id) }
  CONFIG_SETTINGS[:ban_appeal_server].each{ |id_name, id| self.const_set(id_name.upcase, id) }
end

Models = Module.new
Models::BanAppeals = Module.new
Dir["./app/models/**/*.rb"].each{ |file| require file }

Dir["./lib/*.rb"].each{ | file| require file }

# Opens IRB with access to 'DB' if a '-c' option was provided
if(ARGV[0] == '-c')
  ARGV.clear
  load './console.rb'
  exit(0)
end

BOT = Discordrb::Commands::CommandBot.new(CONFIG_SETTINGS)

Dir['./app/**/*.rb'].each{ |file| load file }
BOT.include! StaffContact
BOT.include! Help
BOT.include! BanAppeals

BOT.ready do 
  BOT.game = "DM me to contact staff"
  puts "Bot started!"
end

Signal.trap 'INT' do BOT.stop end

BOT.run