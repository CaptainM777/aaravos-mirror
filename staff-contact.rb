module StaffContact
  extend Discordrb::EventContainer
  extend Discordrb::Commands::CommandContainer

  mention do |event|
    event.respond "Mention test"
  end

  command :test do |event|
    event.respond "Test"
  end
end