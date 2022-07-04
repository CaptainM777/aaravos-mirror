# ban_appeal.rb - Allows users to appeal their ban and speak with the staff through the bot.
require 'securerandom'

module BanAppeals
  extend Discordrb::EventContainer
  extend Discordrb::Commands::CommandContainer
  include ServerSettings
  include Models::BanAppeals

  def self.get_user_id(embed)
    return embed.footer.text.delete_prefix("User ID:").strip
  end

  def self.get_ban(user)
    BOT.server(SERVER_ID).bans.find{ |ban| ban.user.id == user.id }
  end

  def self.format_message(message)
    if !message.attachments.empty?
      attachment_urls = message.attachments.map{ |attachment| attachment.url }
      "#{message.content}\n#{attachment_urls.join("\n")}"
    else
      message.content
    end
  end

  # User initially sends a ban appeal
  message in: BAN_APPEAL_CHANNEL_ID do |event|
    next if !event.user.bot_account?

    ban_appeal_embed = event.message.embeds[0]
    banned_user = BOT.user(get_user_id(ban_appeal_embed))

    if !get_ban(banned_user)
      begin
        banned_user.dm <<~MESSAGE
        You are not banned from the Dragon Prince server. Your appeal was not sent to the staff. Please contact 
        <@260600155630338048> (Captain M#0854) for more assistance.
        MESSAGE
      rescue Discordrb::Errors::NoPermission
      end
      next
    end

    ban_appeal_channel = BOT.server(SERVER_ID).create_channel(
      "ban-appeal-#{banned_user.distinct}",
      topic: "Ban appeal for #{banned_user.mention}",
      parent: MOD_CATEGORY_ID
    )
    ban_appeal_channel.send("**#{banned_user.mention} (#{banned_user.distinct}) would like to appeal their ban.**")

    dm_channel = banned_user.dm
    ban_appeal_id = Time.now.to_i

    server_ban = BOT.get_ban(banned_user.id)
    server_ban_reason = server_ban.reason ? server_ban.reason : "No reason given."

    ban_appeal_fields = ban_appeal_embed.fields
    ban_appeal_fields << Discordrb::Webhooks::EmbedField.new(name: "Ban Reason", value: server_ban_reason)
    ban_appeal_content = ban_appeal_fields.map{ |field| "**#{field.name}**\n#{field.value}" }.join("\n\n")

    Appeal.create(
      id: ban_appeal_id,
      user_id: banned_user.id, 
      staff_channel_id: ban_appeal_channel.id, 
      dm_channel_id: dm_channel.id,
      content: ban_appeal_content,
      submission_time: event.message.timestamp
    )
    
    ban_appeal_channel.send_embed do |embed|
      embed.author = {
        name: ban_appeal_embed.author.name,
        icon_url: ban_appeal_embed.author.icon_url
      }
      embed.footer = {
        text: ban_appeal_embed.footer.text
      }
      ban_appeal_fields.each{ |em| embed.add_field(name: em.name, value: em.value) }
      embed.timestamp = ban_appeal_embed.timestamp
    end

    note_to_staff = ban_appeal_channel.send <<~MESSAGE
    Note to staff: Any messages sent here will be sent to the banned user. **The bot will react with a '✅' if the message was successfully sent.**

    Use `?accept <this channel's ID>` in another channel if you want to accept the appeal. If this option is chosen, then the user will be informed of it, unbanned from this server, and sent an invite link.

    Use `?reject <this channel ID>` in another channel if you want to reject the appeal. If this option is chosen, then the user will be informed of it and banned from the ban appeal server.
    MESSAGE

    note_to_staff.pin

    begin
      dm_channel.send <<~MESSAGE
      Your ban appeal has been sent to the staff. All communication between you and staff will occur through this DM.
      If you want to send a message to them, send it here. **The bot will react with a '✅' if the message was successfully sent.** 

      If your appeal gets approved, you will be informed about it, unbanned from the server, and sent an invite link to the server.
      If you appeal gets rejected, you will be informed about it and banned from the appeal server.
      MESSAGE
    rescue Discordrb::Errors::NoPermission
      BOT.user(CAP_ID).dm "A ban appeal was sent, and #{banned_user.mention} (#{banned_user.id}) has their DM's closed. Please contact them."
    end
  end

  # Staff member sends message to banned user
  message do |event|
    next if event.user.bot_account? || !(ban_appeal = Appeal[staff_channel_id: event.channel.id])
    dm_channel = BOT.channel(ban_appeal[:dm_channel_id])
    formatted_message = format_message(event.message)

    begin
      dm_channel_message = dm_channel.send("**#{event.user.distinct}:** #{formatted_message}")
    rescue Discordrb::Errors::NoPermission
      BOT.user(CAP_ID).dm "A staff member tried to send a message to a banned user in channel #{event.channel.mention} (#{event.channel.name}), " +
      "but either their DM's are closed or they left the ban appeal server. Please contact them."
      event.respond <<~DESCRIPTION
      This user either has their DM's closed, or they left the ban appeal server. Messages sent here won't reach them. 
      Cap has been contacted.
      DESCRIPTION
    rescue Discordrb::Errors::InvalidFormBody
      event.message.reply!(
        "Your message wasn't sent to the banned user because it's too long. Please keep your message under 2000 characters.",
        mention_user: true
      )
    else
      appeal_message = Message.create(
        id: event.message.id,
        dm_channel_message_id: dm_channel_message.id,
        author_id: event.user.id,
        content: event.message.content
      )

      ban_appeal.add_message(appeal_message)

      if !event.message.attachments.empty?
        event.message.attachments.each do |attachment| 
          appeal_message.add_attachment(Attachment.create(url: attachment.url, filename: attachment.filename))
        end
      end

      event.message.react('✅')
    end
  end

  # Banned user sends message to staff
  message do |event|
    next if event.user.bot_account? || !(ban_appeal = Appeal[dm_channel_id: event.channel.id])
    staff_channel = BOT.channel(ban_appeal[:staff_channel_id])
    formatted_message = format_message(event.message)

    begin
      staff_channel_message = staff_channel.send("**#{event.user.distinct}:** #{formatted_message}")
    rescue Discordrb::Errors::InvalidFormBody
      event.message.reply!(
        "Your message wasn't sent to the staff because it's too long. Please keep your message under 2000 characters.",
        mention_user: true
      )
    else
      appeal_message = Message.create(
        id: event.message.id, 
        staff_channel_message_id: staff_channel_message.id,
        author_id: event.user.id,
        content: event.message.content
      )

      ban_appeal.add_message(appeal_message)

      if !event.message.attachments.empty?
        event.message.attachments.each do |attachment|
          appeal_message.add_attachment(Attachment.create(url: attachment.url, filename: attachment.filename))
        end
      end

      event.message.react('✅')
    end
  end

  # Banned user or staff edits a message
  message_edit do |event|
    next if !(appeal_message = Message[event.message.id])
    appeal_message.add_message_edit(
      MessageEdit.create(
        id: Time.now.to_i,
        content: event.message.content
      )
    )

    channel_to_search_for_message_in = BOT.channel(appeal_message.get_surrogate_message_channel_id)
    message_to_be_edited = channel_to_search_for_message_in.load_message(appeal_message.get_surrogate_message_id)

    appeal = Appeal[appeal_message.appeal_id]
    if message_to_be_edited.nil?
      puts <<~LOG
      Unable to find message. Information about the ban appeal model and ban appeal message model:
      Ban appeal model: #{appeal.inspect} # Fix
      Ban appeal message model: #{appeal_message.inspect}
      LOG
    end
    
    message_to_be_edited.edit("**#{event.user.distinct}:** #{event.message.content}")

    if appeal.dm_channel_id == event.channel.id
      message_to_be_edited.reply!(
        <<~MESSAGE
        **#{event.user.distinct} has edited their message:**
        #{appeal_message.compare_edits}
        MESSAGE
      )
    end
  end

  # Banned user or staff deletes a message
  message_delete do |event|
    next if !(appeal_message = Message[event.id])
    appeal_message.deleted = true
    appeal_message.save

    appeal = Appeal[appeal_message.appeal_id]
    # Banned user deletes message
    if appeal.dm_channel_id == event.channel.id
      staff_channel = BOT.channel(appeal.staff_channel_id)
      message_to_mark_as_deleted = staff_channel.load_message(appeal_message.staff_channel_message_id)
      if message_to_mark_as_deleted.nil?
        puts <<~LOG
        Unable to find message. Information about the ban appeal model and ban appeal message model:
        Ban appeal model: #{appeal.inspect}
        Ban appeal message model: #{appeal_message.inspect}
        LOG
      end

      message_to_mark_as_deleted.edit("**(deleted)** #{message_to_mark_as_deleted.content}")
    end
  end

  # Private ban appeal channel gets deleted by a staff member
  channel_delete do |event|
    next if !Appeal[staff_channel_id: event.id]
    dm_channel = BOT.channel(Appeal[staff_channel_id: event.id][:dm_channel_id])
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

  command :accept, allowed_roles: ALLOWED_ROLES, min_args: 1 do |event, channel_id|
    break if event.server.nil? || !(appeal = Appeal[staff_channel_id: channel_id.to_i])

    ban_appeal_logger = BanAppealLogger.new(appeal, event.user, :accepted)
    ban_appeal_logger.log_ban_appeal

    # Gets an invite that never expires and isn't invalid
    invite = event.server.invites.select{ |invite| invite.max_age == 0 && !invite.revoked? }[0]
    if invite.nil?
      invite = BOT.channel(RULES_CHANNEL_ID).make_invite(0, 0, false, false, "Ban appeal accepted")
    end

    appeal_sender = BOT.user(appeal.user_id)
    begin
      event.server.unban(appeal_sender, "Ban appeal accepted")
    rescue Discordrb::Errors::UnknownError
    end

    begin
      appeal_sender.dm("Your ban appeal has been accepted. Server invite: #{invite.url}")
    rescue Discordrb::Errors::NoPermissions
      BOT.user(CAP_ID).dm "The appeal for #{appeal_sender.distinct} (#{appeal_sender.id}) has been approved, " +
      "but their DM's are closed. Please contact them."
    end

    appeal.destroy
    BOT.channel(channel_id).delete

    event.respond "The appeal for **#{appeal_sender.distinct}** (#{appeal_sender.mention}) has been approved."
  end

  command :reject, allowed_roles: ALLOWED_ROLES, min_args: 1 do |event, channel_id|
    break if event.server.nil? || !(appeal = Appeal[staff_channel_id: channel_id.to_i])

    ban_appeal_logger = BanAppealLogger.new(appeal, event.user, :rejected)
    ban_appeal_logger.log_ban_appeal

    appeal_sender = BOT.user(appeal.user_id)

    begin
      appeal_sender.dm("Your ban appeal has been rejected. You have been banned from the ban appeal server.")
    rescue Discordrb::Errors::NoPermissions
      BOT.user(CAP_ID).dm "The appeal for #{appeal_sender.distinct} (#{appeal_sender.id}) has been rejected, " +
      "but their DM's are closed. Please contact them."
    end

    BOT.server(BAN_APPEAL_SERVER_ID).ban(appeal_sender, 0, reason: "Ban appeal rejected")

    appeal.destroy
    BOT.channel(channel_id).delete

    event.respond "The appeal for **#{appeal_sender.distinct}** (#{appeal_sender.mention}) has been rejected."
  end
end