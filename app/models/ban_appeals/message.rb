class Models::BanAppeals::Message < Sequel::Model
  unrestrict_primary_key

  one_to_one :appeal
  one_to_many :message_edits
  one_to_many :attachments

  def get_surrogate_message_channel_id
    appeal = Models::BanAppeals::Appeal[appeal_id]
    staff_channel_message_id ? appeal.staff_channel_id : appeal.dm_channel_id
  end

  def get_surrogate_message_id
    staff_channel_message_id ? staff_channel_message_id : dm_channel_message_id
  end

  def all_edits
    message_edits_dataset.all
  end

  def all_attachments
    attachments_dataset.all
  end

  def compare_edits
    before, after = nil
    if all_edits.size > 1
      return "**Before:** `#{all_edits[-2].content}`\n**After:** `#{all_edits[-1].content}`"
    else
      return "**Before:** `#{content}`\n**After:** `#{all_edits[-1].content}`"
    end
  end

  # A single logged message looks like this assuming it's deleted, has attachments, and has edits:
  # (deleted) Captain M#0854: hello dode
  # 
  # Attachments:
  # 1) [url]
  # 2) [url]
  # 3) [url]
  # ...and so on
  # 
  # Edited Versions:
  # 1) hello dlde
  # 
  # 2) hello dkde

  # 3) hello dude

  # ...and so on
  def format
    formatted_message = "#{deleted ? "(deleted) " : ""}#{BOT.user(author_id).distinct}: #{content}"

    if !all_attachments.empty?
      all_attachments.each_with_index do |attachment, index|
        image_url = ImageArchiver.new(attachment.url, attachment.filename).convert_cdn_to_imgur
        if index == 0
          formatted_message << "\n\nAttachments:\n#{index + 1}) #{image_url}"
        else
          formatted_message << "\n#{index + 1}) #{image_url}"
        end
      end
    end

    if !all_edits.empty?
      all_edits.each_with_index do |edit, index|
        if index == 0
          formatted_message << "\n\nEdited Versions:\n#{index + 1}) #{edit.content}"
        else
          formatted_message << "\n\n#{index + 1}) #{edit.content}"
        end
      end
    end

    formatted_message
  end

  def before_destroy
    attachments.each{ |attachment| a.destroy }
    message_edits.each{ |edit| edit.destroy }
    super
  end
end