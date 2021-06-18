# console.rb - Contains all the logic related to interacting with the database through IRB.
require 'sequel' 
require 'irb'

Dir["./models/*.rb"].each{ |file| require file }

module TableShortcuts
  def all
    CHAT_SESSIONS.all
  end

  def alleach
    CHAT_SESSIONS.all.each{ |entry| puts entry }
    nil
  end

  def shortcuts
    puts <<~SHORTCUTS
    ****************************************
    Shortcuts:
    * all - alias for CHAT_SESSIONS.all
    * alleach - alias for calling CHAT_SESSIONS.all.each{ |entry| puts entry }
    * shortcuts [alias: sc] - shows all the shortcut commands
    ****************************************
    SHORTCUTS
  end
  
  alias :sc :shortcuts
end

puts "The database can be accessed using 'DB', and models can be accessed using their name. " +
"Use 'shortcuts' or 'sc' to see the list of shortcut commands that can be used."
include TableShortcuts

# Redirects standard error to /dev/null because an 'uncaught throw' error was being shown every time I tried to exit IRB;
# I currently don't have a solution to this problem, so this will have to do for now.
$stderr.reopen('/dev/null', 'w') 
IRB.start