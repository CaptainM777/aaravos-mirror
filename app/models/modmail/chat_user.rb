class ChatUser < Sequel::Model
  unrestrict_primary_key

  one_to_one :chat_channel
end