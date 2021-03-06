# Configuration handler for HiRISE/PIRL hosts

# Neede for the "get" command
require 'net/http'
require 'uri'

require 'configbot/basehandler'
require 'configbot/commands'

module HiBot

  ##############################################################################
  # Response Handlers for commands
  ##############################################################################
  class CommandResponseHandler < ResponseHandler

    def handle(text)
      keyword = text.split.shift
      commands = BotCommands::CommandList.commandsByName

      action = commands[ keyword ]
      if action
        command = action.new( acl_criteria(), @sess )
        return command.exec(text)
      end

      unrecognizedResponse( text )
    end

    def cleanup(text)
      @client.cleanup(text)
    end

    def show_help(text)
      topic = text.split
      if topic.length <= 1
        commands = @responses.keys.sort.join(", ")
        say("available commands: #{commands}")
      else
        if @contextual_help[topic[1]]
          say("#{@contextual_help[topic[1]]}")
        else
          say("contextual help not yet available for #{topic[1]}")
        end
      end
    end

    # When we don't know what to say, say this
    def unrecognizedResponse( text )
      print "Unrecognized Response : #{text}"
      #say("For help, simply type: help")
    end
  end

  class MUCResponseHandler < CommandResponseHandler
    def init_acl_criteria( acl_criteria )
      super( acl_criteria )
    end

    def joinedRoom( nick )
    end

    def leftRoom( nick )
    end

    # Returns true if a message should be handled privately (WRT MUC)
    #   -- if we return "yes" then this instance doesn't handle(text)
    #   The MUCSession uses this
    def handlePrivately?(text)
      keyword = text.split.shift
      commands = BotCommands::CommandList.commandsByName
      action = commands[ keyword ]
      if action
        return action.handlePrivately?(text)
      end
    end

    def roomCan?(text, nick)
      keyword = text.split.shift
      commands = BotCommands::CommandList.commandsByName
      action = commands[ keyword ]
      if ! action
        return false
      end

      acl_criteria = @acl_criteria
      acl_criteria[ :user_role ] = @sess.muc.role( nick )
      return action.new( acl_criteria, @sess ).can?( acl_criteria )
    end

    # When we don't know what to say, don't say anything
    def unrecognizedResponse( text )
    end
  end

end
