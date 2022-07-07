# staff_contact.rb - Allows users to contact the staff or admins through a private channel created by the bot.
require 'securerandom'

module StaffContact
  extend Discordrb::EventContainer
  extend Discordrb::Commands::CommandContainer
  include ServerSettings

  SERVER = BOT.server(SERVER_ID)
  here_ping = "@here"
  active_prompts = []

  def self.user_enable_read_perms(user)
    Discordrb::Overwrite.new(user, allow: Discordrb::Permissions.new([:read_messages]))
  end

  def self.create_mod_overwrite(mod_role)
    allow = Discordrb::Permissions.new [:read_messages]
    deny = Discordrb::Permissions.new [:manage_channels]
    Discordrb::Overwrite.new(mod_role, allow: allow, deny: deny)
  end

  def self.create_contact_channel(user, chat_type)
    channel_name = chat_type == :staff ? "chat-#{user.distinct}" : "chat-admin-#{user.distinct}"
    mod_category = SERVER.categories.find{ |category| category.id == MOD_CATEGORY_ID }

    user_enable_read_perms_overwrite = user_enable_read_perms(user)
    mod_overwrite = create_mod_overwrite(SERVER.role(MOD_ROLE_ID))
    contact_channel_overwrites = [
      user_enable_read_perms_overwrite,
      Discordrb::Overwrite.new(SERVER.everyone_role, deny: Discordrb::Permissions.new([:read_messages]))
    ]
    contact_channel_overwrites << mod_overwrite if chat_type == :staff

    contact_channel = SERVER.create_channel(
      channel_name,
      topic: "Chat with #{user.mention}",
      parent: MOD_CATEGORY_ID,
      permission_overwrites: contact_channel_overwrites
    )

    return contact_channel
  end

  message do |event|
    # Skips if the message was sent on the server, the user has an active prompt open, the user is the bot,
    # the user already has an open chat with the staff, or the user sent in a ban appeal.
    next if !event.server.nil? || active_prompts.include?(event.user.id) ||
             event.user.id == BOT.profile.id || ChatUser[event.user.id] ||
             BOT.get_ban(event.user.id)
    active_prompts << event.user.id

    prompt = event.respond "Who would you like to contact? Respond with the number that corresponds to the option you want: " +
    "\n```1 - Contact the entire staff (admins and mods) \n2 - Contact just the admins\n3 - Cancel```"

    user_response = nil
    loop do
      user_response = (event.user.await!(timeout: 30))&.content
      if user_response.nil?
        user_response = :timeout
        event.respond "**Your session has timed out. Send a message here again if you still want to contact either the staff or admins.**"
        break
      elsif (1..3).include?(user_response.to_i)
        if user_response.to_i == 1
          user_response = :staff
        elsif user_response.to_i == 2
          user_response = :admins
        else
          user_response = :cancelled
          prompt.delete
          event.respond "**Cancelled.**"
        end
        break
      else
        event.respond "**Invalid response. Please respond with 1, 2, or 3.**"
      end
    end

    if user_response == :cancelled || user_response == :timeout
      active_prompts.delete(event.user.id)
      next
    end

    contact_channel = create_contact_channel(event.user, user_response)
    first_message = contact_channel.send("#{here_ping} **#{event.author.mention} would to speak with the #{user_response.to_s}.**")
    chat_channel = ChatChannel.create(
      id: contact_channel.id, 
      creation_time: Time.now, 
      admin?: user_response == :staff ? false : true
    )
    chat_channel.chat_user = ChatUser.create(id: event.user.id, distinct: event.user.distinct)
    event.respond "**A private channel has been created on the server for you and the #{user_response.to_s}:** #{first_message.jump_url}"

    active_prompts.delete(event.user.id)
  end

  command :newchat, allowed_roles: ALLOWED_ROLES do |event, *args|
    break if event.server.nil? || args.empty?
    user = BOT.get_member(args[0])
    break if user.nil? || ChatUser[user.id]
    
    chat_type = nil
    if ["admins", "admin"].include?(args[1]&.downcase) && event.user.role?(ADMIN_ROLE_ID)
      chat_type = :admins
    else
      chat_type = :staff
    end

    contact_channel = create_contact_channel(user, chat_type)
    event.respond "**A chat channel has been created for #{user.distinct}.**"
    contact_channel.send("**#{user.mention} the #{chat_type.to_s} would like to speak with you.**")
    chat_channel = ChatChannel.create(
      id: contact_channel.id,
      creation_time: Time.now,
      admin?: chat_type == :staff ? false : true
    )
    chat_channel.chat_user = ChatUser.create(id: user.id, distinct: user.distinct)
    nil
  end

  channel_delete do |event|
    next if !(chat_channel = ChatChannel[event.id])
    chat_user = BOT.user(chat_channel.chat_user.id)
    chat_channel.destroy

    begin
      chat_user.dm "**A staff member has manually deleted the channel used to contact you. Send a message here to contact the staff or the admins again.**"
    rescue Discordrb::Errors::NoPermission
      puts "Error DM'ing user. They likely have DM's turned off for this server, or left."
      puts "***Additional Information***\n" +
      "Chat User: #{chat_channel.chat_user.distinct} (#{chat_channel.chat_user.id})\n" +
      "Timestamp: #{Time.now}\n"
      puts "****************************"
    end
  end

  command :end, allowed_roles: ALLOWED_ROLES do |event|
    break if !(chat_channel = ChatChannel[event.channel.id])
    break if chat_channel.admin? && event.user.role?(MOD_ROLE_ID)
    channel_history = event.channel.full_history
    # Removes the initial message that either pings @here or just pings the user
    channel_history.shift
    channel_history.reject!{ |message| message.content.start_with?("?end") }

    chat_user = BOT.user(chat_channel.chat_user.id)
    file_name = "log-#{SecureRandom.uuid}.txt"
    file_path = "./logs/#{chat_channel.admin? ? "admins" : "staff"}/#{file_name}"
    url = "http://#{ENV['IP_ADDRESS']}:#{ENV['PORT']}/#{file_path.delete_prefix("./logs/")}"

    File.open(file_path, "w") do |file|
      file.write(
        "Log of chat with #{chat_user.distinct} (#{chat_user.id}).\n" +
        "Chat started: #{chat_channel.creation_time.strftime('%Y-%m-%d %H:%M:%S +0000')}\n" +
        "Chat ended: #{Time.now.strftime('%Y-%m-%d %H:%M:%S +0000')}\n\n"
      )
      
      channel_history.each do |message|
        if !message.attachments.empty?
          attachment_urls = message.attachments.map!{ |attachment| attachment.url }
          file.write("#{message.author.distinct} - #{message.content}\n#{attachment_urls.join("\n")}\n---------------------------------------\n")
        else
          file.write("#{message.author.distinct} - #{message.content}\n---------------------------------------\n")
        end
      end

      file.write("\nChat ended by #{event.user.distinct}.")
    end

    log_channel = BOT.channel(chat_channel.admin? ? CHAT_LOG_ADMINS_CHANNEL_ID : CHAT_LOG_CHANNEL_ID)
    caption = "**Log of chat with user `#{chat_user.distinct}`**\n**View:** #{url}"
    log_channel.send_file(File.open(file_path), caption: caption)

    begin
      chat_user.dm("**Your chat has been ended by a staff member. Send another message here to talk to the entire staff or the admins again.**")
    rescue 
      puts "Error DM'ing user. They likely have DM's turned off for this server, or left."
      puts "***Additional Information***\n" +
      "Chat User: #{chat_channel.chat_user.distinct} (#{chat_channel.chat_user.id})\n" +
      "Timestamp: #{Time.now}\n"
      puts "****************************"
    end

    chat_channel.destroy
    event.respond "**Chat logged to #{log_channel.mention}. This channel will be deleted in 5 seconds.**"
    sleep 5
    event.channel.delete
    nil
  end

  # Commands for my use only

  command :togglehereping, aliases: [:togglehere] do |event|
    break if event.user.id != CAP_ID
    if here_ping == "@here"
      here_ping = "@ here"
      event << "**'here' pings have been turned off.**"
    else
      here_ping = "@here"
      event << "**'here' pings have been turned on.**"
    end
  end

  command :showherepingsetting, aliases: [:showheresetting, :showhere] do |event|
    break if event.user.id != CAP_ID
    here_ping == "@here" ? event << "**'here' pings are enabled.**" : event << "**'here' pings are disabled.**"
  end
end