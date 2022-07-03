class Models::BanAppeals::Appeal < Sequel::Model
  unrestrict_primary_key
  
  one_to_many :messages

  def all_messages
    messages_dataset.all
  end

  def format_messages
    return all_messages.map{ |message| message.format }
  end

  def before_destroy
    messages.each{ |message| message.destroy}
    super
  end
end