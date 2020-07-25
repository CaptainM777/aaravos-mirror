require 'sequel'
require 'discordrb'

# The database constant is declared globally so it can be easily accessed by other files
DB ||= Sequel.sqlite('data.db')

module Bot
  if(ARGV[0] == '-c')
    ARGV.clear
    load './console.rb'
    exit(0)
  end

  require_relative 'config.rb'
  bot = Discordrb::Commands::CommandBot.new(CONFIG_SETTINGS)

  load './staff-contact.rb'
  bot.include! StaffContact

  puts "Bot started!"
  bot.run
end