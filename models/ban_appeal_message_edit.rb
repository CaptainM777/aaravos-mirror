class BanAppealMessageEdit < Sequel::Model
  unrestrict_primary_key
  one_to_many :ban_appeal_message_edit
end