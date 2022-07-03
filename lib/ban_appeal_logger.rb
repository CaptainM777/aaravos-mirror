# ban_appeal_logger.rb - Handles all operations relating to the logging of ban appeals to text files.

module BanAppeals
  class BanAppealLogger
    def initialize(appeal, staff_member_logging, appeal_outcome)
      @appeal = appeal
      @banned_user = BOT.user(@appeal.user_id)
      @staff_member_logging = staff_member_logging
      @appeal_outcome = appeal_outcome
      @full_log = ""
    end

    def retrieve_ban_appeal_conversation
      @appeal.format_messages
    end

    def log_ban_appeal
      @full_log << <<~LOG
      Log of ban appeal for #{@banned_user.distinct} (#{@banned_user.id}).
      Ban Appeal Sent: #{@appeal.submission_time.strftime('%Y-%m-%d %H:%M:%S +0000')}
      Ban Appeal Logged: #{Time.now.strftime('%Y-%m-%d %H:%M:%S +0000')}

      Result: #{@appeal_outcome == :accepted ? "Accepted" : "Rejected"} by #{@staff_member_logging.distinct}

      ================

      Ban Appeal Content:

      #{@appeal.content}

      ================

      The original version of each message is shown, with edited versions appearing under "Edited Versions" ordered from oldest to newest.

      Ban Appeal Conversation:

      #{retrieve_ban_appeal_conversation.join("\n---------------------------------------\n")}
      LOG

      file_name = "ban-appeal-#{SecureRandom.uuid}.txt"
      file_path = "./logs/ban_appeals/#{file_name}"
  
      File.open(file_path, "w"){ |file| file.write(@full_log) }

      log_channel = BOT.channel(ServerSettings::MIRROR_BAN_APPEAL_LOG_CHANNEL_ID)
      caption = "**Log of ban appeal for user `#{@banned_user.distinct}`**"
      log_channel.send_file(File.open(file_path), caption: caption)
    end
  end
end