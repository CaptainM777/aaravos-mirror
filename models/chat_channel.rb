class ChatChannel < Sequel::Model
  unrestrict_primary_key

  one_to_one :chat_user

  def before_destroy
    chat_user.delete
    super
  end
end