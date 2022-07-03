# extensions.rb - This file contains extensions to existing Discordrb or Sequel classes and modules.

class Discordrb::Message
  def create_reactions(*emotes)
    return if emotes.empty?
    emotes.each{ |emote| react(emote) }
  end

  # Creates a message link for a given message.
  # @return  [String]   The url.
  def jump_url
    return "https://discordapp.com/channels/#{self.channel.server.id}/#{self.channel.id}/#{self.id}"
  end
end

class Discordrb::Channel
  def full_history(oldest_first=true)
    channel_history = []
    first_time = true

    loop do
      if first_time
        channel_history += history(100)
        first_time = false
      else
        last_message = channel_history[-1]
        break if history(100, before_id=last_message.id).empty?
        channel_history += history(100, before_id=last_message.id)
      end
    end

    return oldest_first ? channel_history.reverse : channel_history 
  end
end

class Discordrb::Bot
  include ServerSettings
  def get_member(member)
    parsed_member = parse_mention(member)
    member(SERVER_ID, parsed_member&.id || member)
  end

  def get_ban(user_id)
    server(SERVER_ID).bans.find{ |ban| ban.user.id == user_id }
  end
end