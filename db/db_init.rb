require 'sequel'

DB = Sequel.sqlite('data.db')

# Creates tables if they don't already exist

# Modmail

DB.create_table?(:chat_channels) do
  Integer :id, primary_key: true
  Time :creation_time
  Boolean :admin?, default: false
end

DB.create_table?(:chat_users) do
  Integer :id, primary_key: true
  String :distinct
  foreign_key :chat_channel_id, :chat_channels
end

# Ban Appeals

DB.create_table?(:appeals) do
  Integer :id, primary_key: true
  Integer :user_id
  Integer :staff_channel_id
  Integer :dm_channel_id
  String :content
  Time :submission_time
end

DB.create_table?(:messages) do
  Integer :id, primary_key: true
  Integer :staff_channel_message_id # Has a non-nil value if the banned user sends the message
  Integer :dm_channel_message_id # Has a non-nil value if the staff sends the message
  Integer :author_id
  String :content
  Boolean :deleted, default: false
  foreign_key :appeal_id, :appeals
end

DB.create_table?(:message_edits) do
  Integer :id, primary_key: true
  String :content
  foreign_key :message_id, :messages
end

DB.create_table?(:attachments) do
  String :url, primary_key: true
  String :filename
  foreign_key :message_id, :messages 
end