# staffcontact.rb - Contains all the logic related to the operation of the staff contact feature.
require_relative '../extensions.rb'
require 'securerandom'
Dir["./models/*.rb"].each{ |file| require file }

module StaffContact
  extend Discordrb::EventContainer
  extend Discordrb::Commands::CommandContainer
  include ServerSettings

  server = BOT.server(SERVER_ID)
  active_prompts = []

  def self.user_enable_read_perms(user)
    Discordrb::Overwrite.new(user, allow: Discordrb::Permissions.new([:read_messages]))
  end

  def self.create_mod_overwrite(mod_role)
    allow = Discordrb::Permissions.new [:read_messages]
    deny = Discordrb::Permissions.new [:manage_channels]
    Discordrb::Overwrite.new(mod_role, allow: allow, deny: deny)
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
  
    channel_name = user_response == :staff ? "chat-#{event.user.distinct}" : "chat-admin-#{event.user.distinct}"
    mod_category = server.categories.find{ |category| category.id == MOD_CATEGORY_ID }

    user_enable_read_perms_overwrite = user_enable_read_perms(event.user)
    mod_overwrite = create_mod_overwrite(server.role(MOD_ROLE_ID))
    contact_channel_overwrites = [
      user_enable_read_perms_overwrite,
      Discordrb::Overwrite.new(server.everyone_role, deny: Discordrb::Permissions.new([:read_messages]))
    ]
    contact_channel_overwrites << mod_overwrite if user_response == :staff

    contact_channel = server.create_channel(
      channel_name,
      topic: "Chat with #{event.user.mention}",
      parent: MOD_CATEGORY_ID,
      permission_overwrites: contact_channel_overwrites
    )

    first_message = contact_channel.send("@ here **#{event.author.mention} would to speak with the #{user_response.to_s}.**")
    chat_channel = ChatChannel.create(
      id: contact_channel.id, 
      creation_time: Time.now, 
      admin?: user_response == :staff ? false : true
    )
    chat_channel.chat_user = ChatUser.create(id: event.user.id, distinct: event.user.distinct)
    event.respond "**A private channel has been created on the server for you and the #{user_response.to_s}:** #{first_message.jump_url}"
    
    active_prompts.delete(event.user.id)
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

  command :end, allowed_roles: [MOD_ROLE_ID, ADMIN_ROLE_ID] do |event|
    break if !(chat_channel = ChatChannel[event.channel.id]) || event.server.nil?
    channel_history = event.channel.full_history
    # Removes the initial "@here @user would like to speak to the staff/admins." message
    channel_history.shift
    channel_history.reject!{ |message| message.content.start_with?("?end") }

    chat_user = BOT.user(chat_channel.chat_user.id)
    file_name = "log-#{SecureRandom.uuid}.txt"
    File.open("./logs/#{file_name}", "w") do |file|
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
    caption = "**Log of chat with user `#{chat_user.distinct}`**"
    log_channel.send_file(File.open("./logs/#{file_name}"), caption: caption)

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
end