# help.rb - Generates parts of the help command using pre-written portions stored in a YAML file.
require 'yaml'

module Help
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include ServerSettings

  HELP_COMMAND = YAML.load_file(File.expand_path('help.yml'))
  master_list_description = HELP_COMMAND["master-list-description"]
  specific_command_footer = HELP_COMMAND["specific-command-footer"]

  HELP_COMMAND.delete("master-list-description")
  HELP_COMMAND.delete("specific-command-footer")

  command :help, allowed_roles: ALLOWED_ROLES do |event, *args|
    break if event.server.nil? 
    
    type = args.join(" ").empty? ? "master" : args.join(" ")

    if type == "master"
      fields = []
      HELP_COMMAND.each do |category, commands|
        category = "**#{category.split("-").map!(&:capitalize).join(" ")}**"
        field = { name: "", value: [] }

        field[:name] = category
        commands.each_value{ |info| field[:value] << info["overview"] }

        field[:value] = field[:value].join("\n")
        fields << field
      end

      fields.reject!{ |hash| hash[:name].empty? && hash[:value].empty? }

      event.send_embed do |embed|
        embed.title = "__Command List__"
        embed.description = master_list_description
        fields.each{ |field| embed.add_field(name: field[:name], value: field[:value]) }
        embed.color = 0xFFD700
      end
    else
      type = type.downcase
      HELP_COMMAND.each_value do |commands|
        command = commands.select{ |command, info| command == type }
        next if command.empty? || !command[type].member?("description")
        event.send_embed do |embed|
          embed.title = "Help: ?#{type}"
          embed.add_field(name: "Arguments", value: command[type]["arguments"])
          embed.add_field(name: "Description", value: command[type]["description"])
          embed.footer = { text: specific_command_footer }
          embed.color = 0xFFD700
        end
        break
      end
      nil # This is here to prevent implicit return
    end
  end
end