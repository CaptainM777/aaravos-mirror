# ban_appeal.rb - 
require_relative '../extensions.rb'
Dir["./models/*.rb"].each{ |file| require file }

module BanAppeals
  extend Discordrb::EventContainer
  extend Discordrb::Commands::CommandContainer
  include ServerSettings

  def self.get_user_id(embed)
    return embed.fields[0].value[/<@\d+>/][/\d+/].to_i
  end

  def self.log_deleted_duplicate_appeal(banned_user)
    ban_appeal_log_channel = BOT.channel(BAN_APPEAL_LOG_CHANNEL_ID)
    ban_appeal_log_channel.send_embed do |embed|
      embed.author = {
        name: banned_user.distinct,
        icon_url: banned_user.avatar_url
      }
      embed.title = "Duplicate Appeal Sent"
      embed.description = banned_user.mention
      embed.footer = {
        text: "User ID: #{banned_user.id}"
      }
      embed.timestamp = Time.now
      embed.color = "#e12a2a"
    end
  end

  def self.get_ban(user)
    BOT.server(SERVER_ID).bans.find{ |ban| ban.user.id == user.id }
  end

  def self.format_message(message)
    if !message.attachments.empty?
      attachment_urls = message.attachments.map!{ |attachment| attachment.url }
      "**#{message.author.distinct}:** #{message.content}\n#{attachment_urls.join("\n")}"
    else
      "**#{message.author.distinct}:** #{message.content}"
    end
  end

  # User initially sends a ban appeal
  message in: BAN_APPEAL_CHANNEL_ID do |event|
    next if !event.user.bot_account?

    ban_appeal_embed = event.message.embeds[0]
    banned_user = BOT.user(get_user_id(ban_appeal_embed))
    if BanAppeal[banned_user.id]
      log_deleted_duplicate_appeal(banned_user)
      event.message.delete
      next
    end

    ban_appeal_channel = BOT.server(SERVER_ID).create_channel(
      "ban-appeal-#{banned_user.distinct}",
      topic: "Ban appeal for #{banned_user.mention}",
      parent: MOD_CATEGORY_ID
    )
    ban_appeal_channel.send("**@ here #{banned_user.mention} (#{banned_user.distinct}) would like to appeal their ban.**")

    dm_channel = banned_user.dm

    BanAppeal.create(
      user_id: banned_user.id, 
      staff_channel_id: ban_appeal_channel.id, 
      dm_channel_id: dm_channel.id
    )

    server_ban = BOT.get_ban(banned_user.id)
    ban_appeal_channel.send_embed do |embed|
      embed.title = ban_appeal_embed.title
      ban_appeal_embed.fields.each{ |em| embed.add_field(name: em.name, value: em.value) }
      embed.add_field(name: "Ban Reason", value: server_ban.reason)
      embed.timestamp = ban_appeal_embed.timestamp
    end

    ban_appeal_channel.send("Note to staff: Any messages sent here will be sent to the banned user.")

    begin
      dm_channel.send <<~MESSAGE
      Your ban appeal has been sent to the staff. All communication between you and staff will occur through this DM.
      If you want to send a message to them, send it here.

      If your appeal gets approved, you will be informed about it, unbanned from the server, and sent an invite link to the server.
      If you appeal gets rejected, you will be informed about it and banned from the appeal server.
      MESSAGE
    rescue Discordrb::Errors::NoPermission
      BOT.user(CAP_ID).dm "A ban appeal was sent, and #{banned_user.mention} (#{banned_user.id}) has their DM's closed. Please contact them."
    end
  end

  # Staff member sends message to banned user
  message do |event|
    next if event.user.bot_account? || !BanAppeal[staff_channel_id: event.channel.id]
    dm_channel = BOT.channel(BanAppeal[staff_channel_id: event.channel.id][:dm_channel_id])
    begin
      dm_channel.send(format_message(event.message))
    rescue Discordrb::Errors::NoPermission
      BOT.user(CAP_ID).dm "A staff member tried to send a message to a banned user in channel #{event.channel.mention}, " +
      "but their DM's are closed. Please contact them."
      event.respond "This user has their DM's closed, so messages sent here won't reach them. Cap has been contacted."
    else
      BanAppealMessage.create(id: event.message.id, content: event.message.content)
    end
  end

  # Banned user sends message to staff
  message do |event|
    next if event.user.bot_account? || !BanAppeal[dm_channel_id: event.channel.id]
    staff_channel = BOT.channel(BanAppeal[dm_channel_id: event.channel.id][:staff_channel_id])
    staff_channel.send(format_message(event.message))
    BanAppealMessage.create(id: event.message.id, content: event.message.content)
  end

  message_edit do |event|
    next if !BanAppealMessage[event.message.id]
  end

  channel_delete do |event|
    next if !BanAppeal[staff_channel_id: event.id]
    dm_channel = BOT.channel(BanAppeal[staff_channel_id: event.id][:dm_channel_id])
    cap_dm_channel = BOT.user(CAP_ID).dm
    begin
      cap_dm_channel.send "A staff member has deleted ban appeal channel #{event.name}. " +
      "Please create a new channel to re-establish contact with the user. DM channel ID: #{dm_channel.id}"

      dm_channel.send "A staff member has manually deleted the ban appeal channel used to communicate with you. For now, messages " +
      "sent here will not reach the staff. A message will be sent to you once communication is re-established with the staff."
    rescue Discordrb::Errors::NoPermission
      cap_dm_channel.send "The ban appeal channel was deleted by a staff member and the banned user couldn't be informed because " +
      "their DM's are closed. Please contact them."
    end
  end
end